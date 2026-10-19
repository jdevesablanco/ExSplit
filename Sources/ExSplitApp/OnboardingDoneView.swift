import SwiftUI
import ExSplitCore

/// Pantalla final del onboarding (PROTOTIPO): animación de «todo listo» + packs de apps que «pair well» con ExSplit.
/// La instalación de los packs aún no está conectada: el botón solo cierra el onboarding.
struct OnboardingDoneView: View {
    var finish: () -> Void
    var startPhase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var phase: Local<Int>          // 0 inicio · 1 anillo · 2 check · 3 contenido
    @StateObject private var rightClick = Local(true)
    @StateObject private var quitAll = Local(false)

    init(finish: @escaping () -> Void, startPhase: Int = 0) {
        self.finish = finish
        self.startPhase = startPhase
        _phase = StateObject(wrappedValue: Local(startPhase))
    }

    private var selected: Int { (rightClick.v ? 1 : 0) + (quitAll.v ? 1 : 0) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            badge
            Text(tr("¡Todo configurado!", "All set!"))
                .font(.system(size: 26, weight: .bold)).padding(.top, 10)
                .opacity(phase.v >= 3 ? 1 : 0).offset(y: phase.v >= 3 ? 0 : 10)
            Text(tr("Haz clic derecho sobre un PDF de ejercicios y elige «Dividir ejercicios con ExSplit».",
                    "Right-click an exercise PDF and choose “Split exercises with ExSplit”."))
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.top, 4).padding(.horizontal, 70)
                .opacity(phase.v >= 3 ? 1 : 0).offset(y: phase.v >= 3 ? 0 : 10)
            packs
                .padding(.top, 24).padding(.horizontal, 44)
                .opacity(phase.v >= 3 ? 1 : 0).offset(y: phase.v >= 3 ? 0 : 18)
            Spacer(minLength: 8)
            Divider()
            HStack {
                Spacer()
                if selected > 0 { Button(tr("Ahora no", "Not now")) { finish() } }
                Button(selected > 0 ? tr("Instalar (\(selected)) y terminar", "Install (\(selected)) and finish") : tr("Terminar", "Finish")) { finish() }
                    .keyboardShortcut(.defaultAction)
            }.padding(16)
        }
        .frame(width: 700, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { if startPhase == 0 { run() } }
    }

    private func run() {
        if reduceMotion { phase.v = 3; return }
        withAnimation(.easeOut(duration: 0.5)) { phase.v = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { phase.v = 2 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { withAnimation(.easeOut(duration: 0.55)) { phase.v = 3 } }
    }

    private var badge: some View {
        let accent = Color.accentColor
        return ZStack {
            Circle().stroke(accent.opacity(0.4), lineWidth: 2).frame(width: 92, height: 92)
                .scaleEffect(phase.v >= 2 ? 2.1 : 1).opacity(phase.v >= 2 ? 0 : 0)
                .animation(.easeOut(duration: 0.9), value: phase.v)
            Circle().stroke(accent.opacity(0.35), lineWidth: 2).frame(width: 92, height: 92)
                .scaleEffect(phase.v >= 2 ? 1.9 : 1).opacity(phase.v == 2 ? 0 : (phase.v == 1 ? 0.6 : 0))
                .animation(.easeOut(duration: 0.9), value: phase.v)
            Circle().fill(accent.opacity(0.12)).frame(width: 92, height: 92)
                .scaleEffect(phase.v >= 1 ? 1 : 0.6).opacity(phase.v >= 1 ? 1 : 0)
            Circle().trim(from: 0, to: phase.v >= 1 ? 1 : 0)
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90)).frame(width: 92, height: 92)
            DoneCheck().trim(from: 0, to: phase.v >= 2 ? 1 : 0)
                .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: 38, height: 28)
        }
        .frame(height: 130)
    }

    private var packs: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(tr("Pairs well with ExSplit", "Pairs well with ExSplit")).font(.headline)
                Text(tr("· hechas por nosotros, gratis y open source", "· made by us, free and open source")).font(.subheadline).foregroundStyle(.secondary)
            }
            PackCard(symbol: "contextualmenu.and.cursorarrow",
                     title: "RightYourClick",
                     detail: tr("Un menú de clic derecho mejorado para Finder, con todas las extensiones en un solo sitio. ExSplit se integra en él.",
                                "An improved Finder right-click menu with all the extensions in one place. ExSplit plugs into it."),
                     isOn: rightClick.binding)
            PackCard(symbol: "power",
                     title: tr("QuitAll", "QuitAll"),
                     badge: tr("Próximamente", "Coming soon"),
                     detail: tr("Cierra todas las apps con un clic, menos las que elijas: esas se ocultan o se dejan como están. Vive en la barra de menús y en el clic derecho del escritorio.",
                                "Quits every app in one click except the ones you pick, which get hidden or left as they are. Lives in the menu bar and in the desktop right-click menu."),
                     isOn: quitAll.binding)
        }
    }
}

private extension Local where T == Bool {
    var binding: Binding<Bool> { Binding(get: { self.v }, set: { self.v = $0 }) }
}

struct PackCard: View {
    let symbol: String
    let title: String
    var badge: String? = nil
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() } } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 14, weight: .semibold))
                        if let badge { Text(badge).font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.25))) }
                    }
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20)).foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.7))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isOn ? Color.accentColor.opacity(0.10) : Color.gray.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isOn ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isOn ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct DoneCheck: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.55))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}
