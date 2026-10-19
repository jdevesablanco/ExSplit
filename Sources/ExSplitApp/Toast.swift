import AppKit
import SwiftUI

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

    var icon: some View {
        Group {
            switch m.kind {
            case .working: ProgressView().controlSize(.small)
            case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            case .error: Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
            }
        }
        .font(.system(size: 20))
        .frame(width: 24, height: 24)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                Text(m.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                if !m.detail.isEmpty {
                    Text(m.detail).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(4).fixedSize(horizontal: false, vertical: true)
                }
                if !m.actions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(m.actions) { a in
                            Button(a.title) { a.run() }.controlSize(.small)
                        }
                    }.padding(.top, 5)
                }
            }
            Spacer(minLength: 0)
            if m.kind != .working {
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 350, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        .padding(10)
    }
}

/// Aviso flotante (sin permisos de notificación): aparece arriba a la derecha y se va solo.
final class ToastController {
    let model = ToastModel()
    var onHidden: (() -> Void)?
    private var panel: NSPanel?
    private var hosting: NSHostingView<ToastView>?
    private var hideWork: DispatchWorkItem?
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
            let h = NSHostingView(rootView: ToastView(m: model, close: { [weak self] in self?.hide() }))
            p.contentView = h
            hosting = h
            panel = p
        }
        DispatchQueue.main.async { [self] in
            guard let p = panel, let h = hosting else { return }
            let size = h.fittingSize
            let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            p.setFrame(NSRect(x: vf.maxX - size.width - 6, y: vf.maxY - size.height - 4, width: size.width, height: size.height), display: true)
            if !p.isVisible { p.alphaValue = 0; p.orderFrontRegardless(); NSAnimationContext.runAnimationGroup { $0.duration = 0.18; p.animator().alphaValue = 1 } }
        }
        if let t = autoHide {
            let w = DispatchWorkItem { [weak self] in self?.hide() }
            hideWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: w)
        }
    }

    func hide() {
        hideWork?.cancel()
        guard let p = panel, p.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; p.animator().alphaValue = 0 }, completionHandler: { [weak self] in
            p.orderOut(nil)
            self?.onHidden?()
        })
    }
}
