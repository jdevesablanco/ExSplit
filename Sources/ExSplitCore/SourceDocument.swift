import Foundation
import CoreGraphics
import PDFKit
import Vision

/// Línea de texto con su caja en puntos, con el origen ARRIBA a la izquierda (y crece hacia abajo).
struct TextLine {
    var text: String
    var rect: CGRect
}

/// Máscara de "tinta" (1 px = 1 pt): sirve para saber dónde acaba el contenido, si hay algo en una zona, etc.
struct InkMask {
    let width: Int
    let height: Int
    let mask: [UInt8]   // 1 = tinta; fila 0 = arriba

    func rowSum(_ y: Int, x0: Int, x1: Int) -> Int {
        guard y >= 0, y < height else { return 0 }
        var s = 0
        let base = y * width
        for x in max(0, x0)..<min(width, x1) { s += Int(mask[base + x]) }
        return s
    }

    /// Longitud de la racha horizontal continua de tinta más larga en la fila `y` (detecta filetes, no texto).
    func longestRun(_ y: Int) -> Int {
        guard y >= 0, y < height else { return 0 }
        var best = 0, cur = 0
        let base = y * width
        for x in 0..<width {
            if mask[base + x] != 0 { cur += 1; if cur > best { best = cur } } else { cur = 0 }
        }
        return best
    }

    func hasInk(x0: Double, y0: Double, x1: Double, y1: Double) -> Bool {
        let ya = max(0, Int(floor(y0))), yb = min(height, Int(ceil(y1)))
        guard ya < yb else { return false }
        for y in ya..<yb where rowSum(y, x0: Int(floor(x0)), x1: Int(ceil(x1))) > 0 { return true }
        return false
    }

    /// Última fila con tinta dentro de [y0, y1).
    func lastInkRow(y0: Double, y1: Double) -> Double? {
        let ya = max(0, Int(floor(y0))), yb = min(height, Int(ceil(y1)))
        guard ya < yb else { return nil }
        for y in stride(from: yb - 1, through: ya, by: -1) where rowSum(y, x0: 0, x1: width) > 0 { return Double(y + 1) }
        return nil
    }

    /// Extensión horizontal de la tinta dentro de [y0, y1).
    func xExtent(y0: Double, y1: Double) -> (Double, Double)? {
        let ya = max(0, Int(floor(y0))), yb = min(height, Int(ceil(y1)))
        guard ya < yb else { return nil }
        var minX = Int.max, maxX = -1
        for y in ya..<yb {
            let base = y * width
            for x in 0..<width where mask[base + x] != 0 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
            }
        }
        return maxX >= 0 ? (Double(minX), Double(maxX + 1)) : nil
    }

    /// Fila en blanco más cercana (hacia arriba) a `target`, sin bajar de `minY`: sirve para cortar entre líneas.
    func blankRow(before target: Double, minY: Double) -> Double? {
        var y = min(height - 1, Int(target))
        let lo = max(0, Int(minY))
        while y >= lo {
            if rowSum(y, x0: 0, x1: width) == 0 { return Double(y) }
            y -= 1
        }
        return nil
    }
}

struct PageInfo {
    let index: Int
    let size: CGSize
    var lines: [TextLine]
    let ink: InkMask
}

/// Un PDF abierto y analizado: texto con posiciones (nativo u OCR) y máscaras de tinta por página.
final class SourceDocument {
    let url: URL
    let cg: CGPDFDocument
    var pages: [PageInfo] = []
    var usedOCR = false
    var title: String?

    init(url: URL, ocr: OCRMode, languages: [String]) throws {
        self.url = url
        guard let pk = PDFDocument(url: url), pk.pageCount > 0 else { throw ExSplitError.cannotOpen(url.lastPathComponent) }
        if pk.isLocked { throw ExSplitError.encrypted(url.lastPathComponent) }
        title = pk.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String

        var workPK = pk
        var workCG: CGPDFDocument
        if let data = SourceDocument.normalizedData(from: pk), let npk = PDFDocument(data: data),
           let prov = CGDataProvider(data: data as CFData), let ncg = CGPDFDocument(prov) {
            workPK = npk; workCG = ncg
        } else if let c = CGPDFDocument(url as CFURL) {
            workCG = c
        } else {
            throw ExSplitError.cannotOpen(url.lastPathComponent)
        }
        self.cg = workCG

        // 1) texto nativo + máscaras
        var native: [[TextLine]] = []
        var sizes: [CGSize] = []
        for i in 0..<workPK.pageCount {
            guard let p = workPK.page(at: i) else { continue }
            let b = p.bounds(for: .mediaBox)
            sizes.append(b.size)
            native.append(SourceDocument.nativeLines(p, size: b.size))
        }
        let totalChars = native.reduce(0) { $0 + $1.reduce(0) { $0 + $1.text.count } }
        let scanned = totalChars < 40 * max(1, native.count)
        let doOCR = (ocr == .always) || (ocr == .auto && scanned)
        usedOCR = doOCR

        for i in 0..<native.count {
            guard let cgp = workCG.page(at: i + 1) else { continue }
            let size = sizes[i]
            let lines = doOCR ? SourceDocument.ocrLines(cgp, size: size, languages: languages) : native[i]
            let ink = SourceDocument.makeInk(cgp, size: size)
            pages.append(PageInfo(index: i, size: size, lines: lines.sorted(by: SourceDocument.readingOrder), ink: ink))
        }
        if pages.isEmpty { throw ExSplitError.cannotOpen(url.lastPathComponent) }
    }

    static func readingOrder(_ a: TextLine, _ b: TextLine) -> Bool {
        let ya = Int(a.rect.minY / 3), yb = Int(b.rect.minY / 3)
        return ya != yb ? ya < yb : a.rect.minX < b.rect.minX
    }

    // MARK: normalización (rotación, cropBox con origen distinto de 0…)

    static func normalizedData(from pk: PDFDocument) -> Data? {
        var needs = false
        for i in 0..<pk.pageCount {
            guard let p = pk.page(at: i) else { continue }
            let c = p.bounds(for: .cropBox), m = p.bounds(for: .mediaBox)
            if p.rotation != 0 || c != m || m.origin != .zero { needs = true; break }
        }
        guard needs, let url = pk.documentURL, let src = CGPDFDocument(url as CFURL) else { return nil }
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return nil }
        var first = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &first, nil) else { return nil }
        for i in 1...src.numberOfPages {
            guard let p = src.page(at: i) else { continue }
            let box = p.getBoxRect(.cropBox)
            let rot = ((p.rotationAngle % 360) + 360) % 360
            let vis = (rot == 90 || rot == 270) ? CGRect(x: 0, y: 0, width: box.height, height: box.width)
                                                : CGRect(x: 0, y: 0, width: box.width, height: box.height)
            var mb = vis
            ctx.beginPDFPage([kCGPDFContextMediaBox as String: Data(bytes: &mb, count: MemoryLayout<CGRect>.size)] as CFDictionary)
            ctx.saveGState()
            ctx.clip(to: vis)
            ctx.concatenate(p.getDrawingTransform(.cropBox, rect: vis, rotate: 0, preserveAspectRatio: true))
            ctx.drawPDFPage(p)
            ctx.restoreGState()
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    // MARK: texto nativo (PDFKit)

    static func nativeLines(_ page: PDFPage, size: CGSize) -> [TextLine] {
        guard let sel = page.selection(for: page.bounds(for: .mediaBox)) else { return [] }
        var out: [TextLine] = []
        for line in sel.selectionsByLine() {
            guard let s = line.string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { continue }
            // PDFKit parte las tildes sueltas de TeX («´») en «líneas» propias: no son texto útil.
            guard s.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
            let r = line.bounds(for: page)
            if r.isEmpty || r.isInfinite { continue }
            out.append(TextLine(text: s, rect: CGRect(x: r.minX, y: size.height - r.maxY, width: r.width, height: r.height)))
        }
        return out
    }

    // MARK: OCR (Vision)

    static func ocrLines(_ page: CGPDFPage, size: CGSize, languages: [String]) -> [TextLine] {
        let scale = 200.0 / 72.0
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return [] }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: scale, y: scale)
        ctx.drawPDFPage(page)
        guard let img = ctx.makeImage() else { return [] }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        if !languages.isEmpty { req.recognitionLanguages = languages }
        let handler = VNImageRequestHandler(cgImage: img, options: [:])
        do { try handler.perform([req]) } catch {
            req.recognitionLanguages = ["en-US"]
            try? handler.perform([req])
        }
        var out: [TextLine] = []
        for o in req.results ?? [] {
            guard let t = o.topCandidates(1).first?.string, !t.isEmpty else { continue }
            let b = o.boundingBox  // normalizado, origen abajo-izquierda
            out.append(TextLine(text: t, rect: CGRect(x: b.minX * size.width, y: (1 - b.maxY) * size.height,
                                                      width: b.width * size.width, height: b.height * size.height)))
        }
        return out
    }

    // MARK: tinta

    static func makeInk(_ page: CGPDFPage, size: CGSize) -> InkMask {
        let w = max(1, Int(ceil(size.width))), h = max(1, Int(ceil(size.height)))
        var buf = [UInt8](repeating: 255, count: w * h)
        buf.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.drawPDFPage(page)
        }
        // fondo = mediana de una muestra; tinta = bastante más oscuro que el fondo
        var sample: [UInt8] = []
        sample.reserveCapacity(buf.count / 7 + 1)
        var i = 0
        while i < buf.count { sample.append(buf[i]); i += 7 }
        sample.sort()
        let bg = Int(sample[sample.count / 2])
        let thr = UInt8(max(0, bg - 30))
        var mask = [UInt8](repeating: 0, count: w * h)
        for k in 0..<buf.count where buf[k] < thr { mask[k] = 1 }
        return InkMask(width: w, height: h, mask: mask)
    }
}
