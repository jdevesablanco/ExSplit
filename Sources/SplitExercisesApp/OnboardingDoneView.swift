import SwiftUI
import SplitExercisesCore

/// Pantalla final del onboarding: animación de «todo listo» + «Combina bien con» (PackCatalog.swift, común a las apps del pack).
struct OnboardingDoneView: View {
    var finish: () -> Void
    var startPhase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var phase: Local<Int>          // 0 inicio · 1 anillo · 2 check · 3 contenido
    @StateObject private var packs = PackStore()

    init(finish: @escaping () -> Void, startPhase: Int = 0) {
        self.finish = finish
        self.startPhase = startPhase
        _phase = StateObject(wrappedValue: Local(startPhase))
    }


    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            badge
            Text(tr("¡Todo configurado!", "All set!"))
                .font(.system(size: 26, weight: .bold)).padding(.top, 10)
                .opacity(phase.v >= 3 ? 1 : 0).offset(y: phase.v >= 3 ? 0 : 10)
            Text(tr("Haz clic derecho sobre un PDF de ejercicios y elige «SplitExercises».",
                    "Right-click an exercise PDF and choose “SplitExercises”."))
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.top, 4).padding(.horizontal, 70)
                .opacity(phase.v >= 3 ? 1 : 0).offset(y: phase.v >= 3 ? 0 : 10)
            PackAppsSection(store: packs, compact: true)
                .padding(.top, 16).padding(.horizontal, 44)
                .opacity(phase.v >= 3 ? 1 : 0).offset(y: phase.v >= 3 ? 0 : 18)
            Spacer(minLength: 8)
            Divider()
            HStack {
                Spacer()
                Button(tr("Terminar", "Finish")) { finish() }
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
