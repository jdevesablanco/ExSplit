import SwiftUI
import ExSplitCore

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

        // «enunciado» simulado
        var y = m
        let lineH = max(2.2, 3.2 * k * 1.2)
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

    private func dot(_ p: LabelPosition) -> some View {
        Button { position = p } label: {
            Circle()
                .fill(position == p ? Color.accentColor : Color.gray.opacity(0.35))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.accentColor.opacity(position == p ? 0.4 : 0), lineWidth: 4))
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
        .padding(10)
        .frame(width: 130, height: 92)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4), lineWidth: 0.7))
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}
