import SwiftUI
import PDFKit
import SplitExercisesCore

/// Mini-hoja que refleja en vivo papel, margen, etiqueta y zona de respuesta.
struct PagePreview: View {
    let s: Settings

    var body: some View {
        GeometryReader { geo in
            let paper = s.paper.size(source: CGSize(width: 595.28, height: 841.89))
            let aspect = paper.width / paper.height
            let w = min(geo.size.width, geo.size.height * aspect)
            let h = w / aspect
            ZStack {
                Canvas { ctx, size in draw(&ctx, size: size, paper: paper) }
                    .frame(width: w, height: h)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, paper: CGSize) {
        let k = size.width / paper.width
        let m = s.margin * k
        let W = size.width, H = size.height
        let ink = Color(white: 0.3).opacity(0.55)

        // área útil (guía muy tenue)
        ctx.stroke(Path(CGRect(x: m, y: m, width: W - 2 * m, height: H - 2 * m)), with: .color(.gray.opacity(0.18)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

        // «enunciado»: ejercicio de ejemplo real (mismo espacio que la maqueta anterior)
        var y = m
        let lineH = max(2.2, 3.2 * k * 1.2)
        let figH = (H - 2 * m) * 0.14
        let stmtEnd = m + lineH * 8 + lineH * 0.5 + figH + lineH + lineH * 4
        if let page = SampleExercise.page {
            let box = page.bounds(for: .mediaBox)
            let availW = W - 2 * m
            let sc = availW / box.width
            let dw = box.width * sc, dh = box.height * sc
            let ox = m + (availW - dw) / 2
            ctx.withCGContext { cg in
                cg.saveGState()
                cg.translateBy(x: ox - box.minX * sc, y: m + dh + box.minY * sc)
                cg.scaleBy(x: sc, y: -sc)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()
            }
            y = m + dh + lineH
        } else {
            let widths: [CGFloat] = [1, 0.97, 0.9, 0.5]
            for (i, f) in widths.enumerated() {
                ctx.fill(Path(roundedRect: CGRect(x: m, y: y, width: (W - 2 * m) * f, height: lineH), cornerRadius: 1), with: .color(i == 0 ? ink.opacity(0.9) : ink))
                y += lineH * 2
            }
            y += lineH * 0.5
            let figH = (H - 2 * m) * 0.14
            ctx.fill(Path(roundedRect: CGRect(x: m + (W - 2 * m) * 0.2, y: y, width: (W - 2 * m) * 0.6, height: figH), cornerRadius: 2), with: .color(.blue.opacity(0.12)))
            ctx.stroke(Path(roundedRect: CGRect(x: m + (W - 2 * m) * 0.2, y: y, width: (W - 2 * m) * 0.6, height: figH), cornerRadius: 2), with: .color(.blue.opacity(0.3)), lineWidth: 0.6)
            y += figH + lineH
            for f: CGFloat in [0.8, 0.7] {
                ctx.fill(Path(roundedRect: CGRect(x: m, y: y, width: (W - 2 * m) * f, height: lineH), cornerRadius: 1), with: .color(ink))
                y += lineH * 2
            }
        }

        // zona de respuesta
        let y0 = y + 6 * k, y1 = H - m - 3 * k
        let gray = Color(white: 0.7).opacity(0.7)
        if y1 - y0 > 10 {
            switch s.answerSpace {
            case .blank: break
            case .lines:
                var yy = y0 + 18 * k
                while yy < y1 { ctx.stroke(Path { $0.move(to: CGPoint(x: m, y: yy)); $0.addLine(to: CGPoint(x: W - m, y: yy)) }, with: .color(gray), lineWidth: 0.5); yy += 24 * k }
            case .grid:
                let step = 14 * k
                var yy = y0
                while yy <= y1 { ctx.stroke(Path { $0.move(to: CGPoint(x: m, y: yy)); $0.addLine(to: CGPoint(x: W - m, y: yy)) }, with: .color(gray), lineWidth: 0.4); yy += step }
                var xx = m
                while xx <= W - m { ctx.stroke(Path { $0.move(to: CGPoint(x: xx, y: y0)); $0.addLine(to: CGPoint(x: xx, y: y1)) }, with: .color(gray), lineWidth: 0.4); xx += step }
            case .dots:
                let step = 14 * k
                var yy = y0
                while yy <= y1 { var xx = m; while xx <= W - m { ctx.fill(Path(ellipseIn: CGRect(x: xx - 0.7, y: yy - 0.7, width: 1.4, height: 1.4)), with: .color(gray)); xx += step }; yy += step }
            }
        }

        // etiqueta
        if s.labelEnabled {
            let text = s.effectiveLabelTemplate.replacingOccurrences(of: "{n}", with: "3").replacingOccurrences(of: "{total}", with: "12").replacingOccurrences(of: "{file}", with: "tema1")
            let fs = max(5, s.labelFontSize * k * 1.0)
            let t = Text(text).font(.system(size: fs)).foregroundColor(Color(white: s.labelGray))
            let inset = min(18.0, max(4.0, s.margin * 0.6)) * k
            let isTop = [.topLeft, .topCenter, .topRight].contains(s.labelPosition)
            let py = isTop ? inset : H - inset
            switch s.labelPosition {
            case .topLeft, .bottomLeft: ctx.draw(t, at: CGPoint(x: m, y: py), anchor: isTop ? .topLeading : .bottomLeading)
            case .topCenter, .bottomCenter: ctx.draw(t, at: CGPoint(x: W / 2, y: py), anchor: isTop ? .top : .bottom)
            case .topRight, .bottomRight: ctx.draw(t, at: CGPoint(x: W - m, y: py), anchor: isTop ? .topTrailing : .bottomTrailing)
            }
        }
    }
}

/// Selector visual de la posición de la etiqueta (6 puntos sobre una hoja).
struct PositionPicker: View {
    @Binding var position: LabelPosition
    var width: CGFloat = 130
    var enabled: Bool = true

    @StateObject private var seedBox = Local([String: UInt64]())

    private func pick(_ p: LabelPosition) {
        seedBox.v["\(p)"] = UInt64.random(in: 1...UInt64.max)
        position = p
    }

    private func dot(_ p: LabelPosition) -> some View {
        let on = position == p
        let seed = seedBox.v["\(p)"] ?? 1
        return Button { pick(p) } label: {
            ZStack {
                Circle().fill(Color.primary.opacity(0.06)).frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color.primary.opacity(0.4), lineWidth: 1.3))
                PenStroke(first: true, seed: seed).trim(from: 0, to: on ? 1 : 0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .animation(.easeOut(duration: 0.14), value: on)
                PenStroke(first: false, seed: seed).trim(from: 0, to: on ? 1 : 0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .animation(.easeOut(duration: 0.16).delay(on ? 0.12 : 0), value: on)
            }
            .frame(width: 18, height: 18)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(p.title)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack { dot(.topLeft); Spacer(); dot(.topCenter); Spacer(); dot(.topRight) }
            Spacer()
            HStack { dot(.bottomLeft); Spacer(); dot(.bottomCenter); Spacer(); dot(.bottomRight) }
        }
        .padding(8)
        .frame(width: width, height: 92)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 0.5))
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }
}


/// Trazo «a mano» de una X: dos líneas curvas y desiguales; cada `seed` da una variante distinta.
struct PenStroke: Shape {
    let first: Bool
    var seed: UInt64 = 1
    private func r(_ i: UInt64) -> CGFloat {
        var x = seed &+ (i &+ 1) &* 0x9E3779B97F4A7C15
        x ^= x >> 30; x = x &* 0xBF58476D1CE4E5B9; x ^= x >> 27; x = x &* 0x94D049BB133111EB; x ^= x >> 31
        return CGFloat(x % 1000) / 1000 - 0.5   // -0.5 ... 0.5
    }
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        var p = Path()
        if first {   // la larga
            p.move(to: pt(0.04 + r(0) * 0.08, 0.08 + r(1) * 0.08))
            p.addQuadCurve(to: pt(0.98 + r(2) * 0.06, 0.96 + r(3) * 0.06), control: pt(0.56 + r(4) * 0.16, 0.38 + r(5) * 0.16))
        } else {     // la corta
            p.move(to: pt(0.88 + r(6) * 0.08, 0.16 + r(7) * 0.08))
            p.addQuadCurve(to: pt(0.22 + r(8) * 0.08, 0.84 + r(9) * 0.08), control: pt(0.50 + r(10) * 0.16, 0.55 + r(11) * 0.16))
        }
        return p
    }
}
