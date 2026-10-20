import AppKit
import SwiftUI
import SplitExercisesCore

struct ToastAction: Identifiable {
    let id = UUID()
    let title: String
    let run: () -> Void
}

final class ToastModel: ObservableObject {
    enum Kind { case working, success, warning, error }
    @Published var kind: Kind = .working
    @Published var title = ""
    @Published var detail = ""
    @Published var actions: [ToastAction] = []
}

struct ToastView: View {
    @ObservedObject var m: ToastModel
    var close: () -> Void
    var hover: (Bool) -> Void
    @State private var hovering = false

    /// Icono de la app (como en una notificación nativa) con una insignia de estado.
    var appIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().interpolation(.high)
                .frame(width: 38, height: 38)
            Group {
                switch m.kind {
                case .working: ProgressView().controlSize(.mini).frame(width: 16, height: 16).background(Circle().fill(.regularMaterial))
                case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.white, .green)
                case .warning: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.white, .orange)
                case .error: Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .red)
                }
            }
            .font(.system(size: 15))
            .offset(x: 4, y: 4)
        }
        .frame(width: 42, height: 42)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            appIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(m.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                    Spacer(minLength: 4)
                    Text(tr("ahora", "now")).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                if !m.detail.isEmpty {
                    Text(m.detail).font(.system(size: 13)).foregroundStyle(.secondary)
                        .lineLimit(4).fixedSize(horizontal: false, vertical: true)
                }
                if !m.actions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(m.actions) { a in
                            Button(a.title) { a.run() }.buttonStyle(NativeNoticeButton())
                        }
                    }.padding(.top, 6)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(width: 344, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 0.5))
        .overlay(alignment: .topLeading) {
            if hovering && m.kind != .working {
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 18, height: 18).background(Circle().fill(.regularMaterial))
                        .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain).offset(x: -6, y: -6).transition(.opacity)
            }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h }; hover(h) }
        .padding(12)
    }
}

/// Botón gris redondeado como los de las notificaciones de macOS.
struct NativeNoticeButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.20 : 0.10)))
    }
}

/// Aviso flotante (sin permisos de notificación): aparece arriba a la derecha y se va solo.
final class ToastController {
    let model = ToastModel()
    var onHidden: (() -> Void)?
    private var panel: NSPanel?
    private var hosting: NSHostingView<ToastView>?
    private var hideWork: DispatchWorkItem?
    private var pendingHide: TimeInterval?
    var isVisible: Bool { panel?.isVisible ?? false }

    func show(_ kind: ToastModel.Kind, title: String, detail: String = "", actions: [ToastAction] = [], autoHide: TimeInterval? = nil) {
        hideWork?.cancel()
        model.kind = kind; model.title = title; model.detail = detail; model.actions = actions
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 370, height: 80),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isFloatingPanel = true
            p.level = .statusBar
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.isReleasedWhenClosed = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let h = NSHostingView(rootView: ToastView(m: model, close: { [weak self] in self?.hide() }, hover: { [weak self] in self?.hoverChanged($0) }))
            p.contentView = h
            hosting = h
            panel = p
        }
        DispatchQueue.main.async { [self] in
            guard let p = panel, let h = hosting else { return }
            let size = h.fittingSize
            let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            let target = NSRect(x: vf.maxX - size.width + 2, y: vf.maxY - size.height + 2, width: size.width, height: size.height)
            if !p.isVisible {
                p.setFrame(target.offsetBy(dx: size.width + 20, dy: 0), display: true)
                p.alphaValue = 1; p.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { $0.duration = 0.32; $0.timingFunction = CAMediaTimingFunction(name: .easeOut); p.animator().setFrame(target, display: true) }
            } else { p.setFrame(target, display: true) }
        }
        pendingHide = autoHide
        scheduleHide(autoHide)
    }

    private func scheduleHide(_ t: TimeInterval?) {
        hideWork?.cancel()
        guard let t else { return }
        let w = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: w)
    }

    /// Con el ratón encima el aviso no se va (como las notificaciones nativas).
    private func hoverChanged(_ inside: Bool) {
        if inside { hideWork?.cancel() } else if pendingHide != nil { scheduleHide(3) }
    }

    func hide() {
        hideWork?.cancel()
        guard let p = panel, p.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; $0.timingFunction = CAMediaTimingFunction(name: .easeIn); p.animator().setFrame(p.frame.offsetBy(dx: p.frame.width + 20, dy: 0), display: true) }, completionHandler: { [weak self] in
            p.orderOut(nil)
            self?.onHidden?()
        })
    }
}
