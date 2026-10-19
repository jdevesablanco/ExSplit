import Foundation
import CoreGraphics
import CoreText

public struct ExerciseRow: Sendable {
    public let n: Int
    public let sourcePages: [Int]       // 1-based
    public let scale: Double
    public let outPages: Int
    public let usedPercent: Int
    public var flagged: Bool { outPages > 1 || scale < 0.9 }
}

public struct SplitReport: Sendable {
    public let pattern: String
    public let usedOCR: Bool
    public let sourcePages: Int
    public let outputPages: Int
    public let rows: [ExerciseRow]
    public var exerciseCount: Int { rows.count }
    public var flaggedCount: Int { rows.filter { $0.flagged }.count }
}

enum Renderer {
    static func render(_ doc: SourceDocument, plan: Plan, settings s: Settings, to url: URL) throws -> SplitReport {
        let srcSize = doc.pages[0].size
        let paper = s.paper.size(source: srcSize)
        let W = Double(paper.width), H = Double(paper.height)
        let margin = s.margin
        let AW = W - 2 * margin, AH = H - 2 * margin
        let cw = plan.x1 - plan.x0
        let gap = 8.0

        var mediaBox = CGRect(x: 0, y: 0, width: W, height: H)
        var info: [String: Any] = [kCGPDFContextCreator as String: "ExSplit"]
        if let t = doc.title { info[kCGPDFContextTitle as String] = t }
        guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, info as CFDictionary) else {
            throw ExSplitError.writeFailed(url.path)
        }

        var outPages = 0
        func newPage() {
            if outPages > 0 { ctx.endPDFPage() }
            ctx.beginPDFPage(nil)
            outPages += 1
        }

        var rows: [ExerciseRow] = []
        let total = plan.exercises.count
        for ex in plan.exercises where !ex.segments.isEmpty {
            let segs = ex.segments
            let tot = segs.reduce(0.0) { $0 + ($1.y1 - $1.y0) } + gap * Double(segs.count - 1)
            var sc = min(1.0, AH / tot, AW / cw)
            if sc < s.minScale { sc = min(1.0, AW / cw) }   // demasiado largo: escala 1 y varias páginas
            // si el ancho es mayor que el área útil el contenido se reduce (sc<1) pero nunca se agranda
            let dx = margin
            var pagesUsed = 0
            var cy = margin

            func startPage(cont: Bool) {
                newPage(); pagesUsed += 1; cy = margin
                if s.labelEnabled {
                    var text = s.effectiveLabelTemplate.replacingOccurrences(of: "{n}", with: String(ex.n))
                        .replacingOccurrences(of: "{total}", with: String(total))
                        .replacingOccurrences(of: "{file}", with: doc.url.deletingPathExtension().lastPathComponent)
                    if cont && !s.labelContinuation.isEmpty { text += " " + s.labelContinuation }
                    drawLabel(ctx, text: text, s: s, W: W, H: H)
                }
            }
            func draw(page pi: Int, y0: Double, y1: Double) {
                guard let src = doc.cg.page(at: pi + 1) else { return }
                let srcH = Double(doc.pages[pi].size.height)
                let h = (y1 - y0) * sc
                let dest = CGRect(x: dx, y: H - (cy + h), width: cw * sc, height: h)
                ctx.saveGState()
                ctx.clip(to: dest)
                ctx.concatenate(CGAffineTransform(a: sc, b: 0, c: 0, d: sc,
                                                  tx: dx - plan.x0 * sc,
                                                  ty: H - cy - (srcH - y0) * sc))
                ctx.drawPDFPage(src)
                ctx.restoreGState()
                cy += h
            }

            startPage(cont: false)
            for (si, seg) in segs.enumerated() {
                var y0 = seg.y0
                while y0 < seg.y1 - 0.5 {
                    let room = (H - margin - cy) / sc
                    let need = seg.y1 - y0
                    if need <= room + 0.01 { draw(page: seg.page, y0: y0, y1: seg.y1); break }
                    if cy > margin + 0.5 && room < 0.25 * AH / sc { startPage(cont: true); continue }
                    var cut = y0 + room
                    if let b = doc.pages[seg.page].ink.blankRow(before: cut, minY: y0 + room * 0.5) { cut = b }
                    if cut <= y0 + 1 { cut = y0 + room }
                    draw(page: seg.page, y0: y0, y1: cut)
                    startPage(cont: true)
                    y0 = cut
                }
                if si < segs.count - 1 { cy += gap * sc }
            }
            drawAnswerSpace(ctx, style: s.answerSpace, x0: margin, x1: W - margin, y0: cy + 10, y1: H - margin - 4, H: H)
            rows.append(ExerciseRow(n: ex.n, sourcePages: Array(Set(segs.map { $0.page + 1 })).sorted(), scale: (sc * 100).rounded() / 100,
                                    outPages: pagesUsed, usedPercent: Int((cy / H * 100).rounded())))
        }
        if outPages > 0 { ctx.endPDFPage() }
        ctx.closePDF()
        if outPages == 0 { throw ExSplitError.emptyResult }
        return SplitReport(pattern: plan.patternName, usedOCR: doc.usedOCR, sourcePages: doc.pages.count, outputPages: outPages, rows: rows)
    }

    // MARK: etiqueta

    static func drawLabel(_ ctx: CGContext, text: String, s: Settings, W: Double, H: Double) {
        let size = CGFloat(s.labelFontSize)
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let color = CGColor(gray: CGFloat(s.labelGray), alpha: 1)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        let tw = Double(CTLineGetTypographicBounds(line, nil, nil, nil))
        let m = s.margin
        let inset = min(18.0, max(4.0, m * 0.6))
        let x: Double
        switch s.labelPosition {
        case .topLeft, .bottomLeft: x = m
        case .topCenter, .bottomCenter: x = (W - tw) / 2
        case .topRight, .bottomRight: x = W - m - tw
        }
        let y: Double
        switch s.labelPosition {
        case .bottomLeft, .bottomCenter, .bottomRight: y = inset
        case .topLeft, .topCenter, .topRight: y = H - inset - Double(size) * 0.75
        }
        ctx.saveGState()
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // MARK: zona de respuesta (rayas, cuadrícula, puntos)

    static func drawAnswerSpace(_ ctx: CGContext, style: AnswerSpace, x0: Double, x1: Double, y0: Double, y1: Double, H: Double) {
        guard style != .blank, y1 - y0 > 40 else { return }
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(gray: 0.82, alpha: 1))
        ctx.setFillColor(CGColor(gray: 0.7, alpha: 1))
        ctx.setLineWidth(0.4)
        // Coordenadas td (arriba->abajo) -> PDF
        func Y(_ td: Double) -> Double { H - td }
        switch style {
        case .lines:
            var y = y0 + 18
            while y <= y1 { ctx.move(to: CGPoint(x: x0, y: Y(y))); ctx.addLine(to: CGPoint(x: x1, y: Y(y))); y += 24 }
            ctx.strokePath()
        case .grid:
            let step = 14.0
            var y = y0; while y <= y1 { ctx.move(to: CGPoint(x: x0, y: Y(y))); ctx.addLine(to: CGPoint(x: x1, y: Y(y))); y += step }
            var x = x0; while x <= x1 { ctx.move(to: CGPoint(x: x, y: Y(y0))); ctx.addLine(to: CGPoint(x: x, y: Y(y1 - (y1 - y0).truncatingRemainder(dividingBy: step)))); x += step }
            ctx.strokePath()
        case .dots:
            let step = 14.0
            var y = y0
            while y <= y1 { var x = x0; while x <= x1 { ctx.fillEllipse(in: CGRect(x: x - 0.6, y: Y(y) - 0.6, width: 1.2, height: 1.2)); x += step }; y += step }
        case .blank: break
        }
        ctx.restoreGState()
    }
}
