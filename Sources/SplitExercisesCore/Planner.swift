import Foundation
import CoreGraphics

struct Marker { var n: Int; var page: Int; var y: Double }
struct Segment { var page: Int; var y0: Double; var y1: Double }   // y arriba->abajo, en puntos de la página origen

/// Resultado del análisis: dónde empieza y acaba cada ejercicio en el PDF original.
struct Plan {
    var patternName: String
    var frameTop: Double
    var frameBottom: Double
    var x0: Double
    var x1: Double
    var exercises: [(n: Int, segments: [Segment])]
}

enum Planner {
    static let autoPatterns: [(String, String, Double)] = [
        ("N.", #"^\s*(\d{1,3})\s*\.(?:\s|$)"#, 0.25),
        ("N)", #"^\s*(\d{1,3})\s*\)(?:\s|$)"#, 0.25),
        ("Ejercicio N", #"^\s*(?:Ejercicio|Problema|Exercise|Problem|Cuesti[oó]n|Question)\s+(\d{1,3})\b"#, 0.40),
    ]

    static func findMarkers(_ doc: SourceDocument, custom: String) throws -> ([Marker], String) {
        var cands = autoPatterns
        if !custom.isEmpty { cands = [("personalizado", custom, 0.5)] }
        var best: ([Marker], String) = ([], "")
        for (name, rx, xfrac) in cands {
            guard let re = try? NSRegularExpression(pattern: rx, options: [.caseInsensitive]) else { throw SplitExercisesError.invalidPattern(rx) }
            var marks: [Marker] = []
            for p in doc.pages {
                for l in p.lines {
                    let ns = l.text as NSString
                    guard let m = re.firstMatch(in: l.text, options: [.anchored], range: NSRange(location: 0, length: ns.length)),
                          m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound,
                          let n = Int(ns.substring(with: m.range(at: 1))) else { continue }
                    if l.rect.minX < p.size.width * xfrac && n == marks.count + 1 {
                        marks.append(Marker(n: n, page: p.index, y: l.rect.minY))
                    }
                }
            }
            if marks.count > best.0.count { best = (marks, name) }
        }
        return best
    }

    /// Zona útil: descarta cabeceras/pies repetidos (texto, numeración, líneas finas).
    static func detectFrame(_ doc: SourceDocument) -> (Double, Double) {
        let H = Double(doc.pages[0].size.height)
        let n = doc.pages.count
        func norm(_ s: String) -> String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let r = t.replacingOccurrences(of: #"\d+"#, with: "#", options: .regularExpression)
            return String(r.prefix(60))
        }
        var cntH: [String: Int] = [:], cntF: [String: Int] = [:]
        for p in doc.pages {
            for l in p.lines {
                let t = norm(l.text); if t.isEmpty { continue }
                if Double(l.rect.maxY) < 0.12 * H { cntH[t, default: 0] += 1 }
                if Double(l.rect.minY) > 0.88 * H { cntF[t, default: 0] += 1 }
            }
        }
        let thr = max(2, n / 2)
        let hdr = Set(cntH.filter { $0.value >= thr }.keys), ftr = Set(cntF.filter { $0.value >= thr }.keys)
        var tops: [Double] = [], bots: [Double] = []
        for p in doc.pages {
            var pt = 0.0, pb = H
            for l in p.lines {
                let t = norm(l.text)
                if hdr.contains(t) && Double(l.rect.maxY) < 0.12 * H { pt = max(pt, Double(l.rect.maxY)) }
                if ftr.contains(t) && Double(l.rect.minY) > 0.88 * H { pb = min(pb, Double(l.rect.minY)) }
            }
            // líneas finas horizontales de cabecera/pie (filetes)
            let w = p.ink.width
            func isThin(_ y: Int) -> Bool {
                p.ink.longestRun(y) > Int(0.3 * Double(w)) && p.ink.longestRun(y - 2) < 3 && p.ink.longestRun(y + 2) < 3
            }
            if !hdr.isEmpty { for y in 0..<Int(0.12 * H) where isThin(y) { pt = max(pt, Double(y) + 1) } }
            if !ftr.isEmpty { for y in Int(0.88 * H)..<p.ink.height where isThin(y) { pb = min(pb, Double(y)) } }
            if pt > 0 { tops.append(pt) }
            if pb < H { bots.append(pb) }
        }
        // mediana entre páginas: una portada o una página atípica no desplaza el marco de todas las demás
        func median(_ a: [Double]) -> Double? { a.isEmpty ? nil : a.sorted()[a.count / 2] }
        var top = median(tops) ?? 0.0
        var bot = median(bots) ?? H
        top = top > 0 ? top + 6 : 0
        bot = bot < H ? bot - 1 : H - 20
        return (top, bot)
    }

    static func contentBottom(_ p: PageInfo, top: Double, bot: Double) -> Double {
        var ys: [Double] = p.lines.filter { Double($0.rect.maxY) < bot && Double($0.rect.minY) > top }.map { Double($0.rect.maxY) }
        if let r = p.ink.lastInkRow(y0: top, y1: bot) { ys.append(r) }
        guard let m = ys.max() else { return top }
        return min(m + 4, bot)
    }

    static func hasContent(_ p: PageInfo, x0: Double, y0: Double, x1: Double, y1: Double) -> Bool {
        let r = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        if p.lines.contains(where: { $0.rect.intersects(r) }) { return true }
        return p.ink.hasInk(x0: x0, y0: y0, x1: x1, y1: y1)
    }

    static func make(_ doc: SourceDocument, settings: Settings) throws -> Plan {
        let (marks0, pname) = try findMarkers(doc, custom: settings.customPattern)
        guard !marks0.isEmpty else { throw SplitExercisesError.noMarkers(doc.url.lastPathComponent) }
        let (top, bot) = detectFrame(doc)
        let pad = 4.0
        if ProcessInfo.processInfo.environment["SPLITEXERCISES_DEBUG"] != nil { FileHandle.standardError.write(Data("frame top=\(top) bot=\(bot) pages=\(doc.pages.count) size=\(doc.pages[0].size)\n".utf8)) }
        let marks = marks0.map { m -> Marker in
            // corte unos puntos por encima del marcador, pero nunca a través de la última línea del ejercicio anterior
            let ink = doc.pages[m.page].ink
            var y = max(0, m.y - pad)
            while y < m.y && ink.rowSum(Int(y), x0: 0, x1: ink.width) > 0 { y += 1 }
            return Marker(n: m.n, page: m.page, y: y)
        }

        // ancho útil
        var xs0: [Double] = [], xs1: [Double] = []
        if doc.usedOCR {
            var a: [Double] = [], b: [Double] = []
            for p in doc.pages { for l in p.lines { a.append(Double(l.rect.minX)); b.append(Double(l.rect.maxX)) } }
            a.sort(); b.sort()
            if !a.isEmpty { xs0 = [a[Int(0.02 * Double(a.count - 1))]]; xs1 = [b[Int(0.98 * Double(b.count - 1))]] }
        } else {
            for p in doc.pages {
                if let (a, b) = p.ink.xExtent(y0: top, y1: bot) { xs0.append(a); xs1.append(b) }
                for l in p.lines where Double(l.rect.maxY) < bot && Double(l.rect.minY) > top { xs0.append(Double(l.rect.minX)); xs1.append(Double(l.rect.maxX)) }
            }
        }
        let W0 = Double(doc.pages[0].size.width)
        let X0 = max(0, (xs0.min() ?? 0) - 12)
        let X1 = min(W0, (xs1.max() ?? W0) + 12)

        var exercises: [(n: Int, segments: [Segment])] = []
        for (k, m) in marks.enumerated() {
            let last = k + 1 == marks.count
            let nextPage = last ? doc.pages.count - 1 : marks[k + 1].page
            let nextY = last ? nil : marks[k + 1].y
            var out: [Segment] = []
            if !last && nextPage == m.page {
                out.append(Segment(page: m.page, y0: m.y, y1: nextY!))
            } else {
                out.append(Segment(page: m.page, y0: m.y, y1: contentBottom(doc.pages[m.page], top: top, bot: bot)))
                let upper = last ? doc.pages.count : nextPage + 1
                if m.page + 1 < upper {
                    for q in (m.page + 1)..<upper {
                        let end = (!last && q == nextPage) ? nextY! : contentBottom(doc.pages[q], top: top, bot: bot)
                        out.append(Segment(page: q, y0: top, y1: end))
                    }
                }
            }
            let kept = out.filter { $0.y1 - $0.y0 > 8 && hasContent(doc.pages[$0.page], x0: X0, y0: $0.y0, x1: X1, y1: $0.y1) }
            exercises.append((m.n, kept))
        }
        return Plan(patternName: pname, frameTop: top, frameBottom: bot, x0: X0, x1: X1, exercises: exercises)
    }
}
