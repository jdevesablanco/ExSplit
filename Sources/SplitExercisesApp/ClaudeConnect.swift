import SwiftUI
import AppKit
import SplitExercisesCore

/// Conexión con Claude: skill para Claude Code + herramienta MCP para la app de Claude (chat y Cowork).
extension Integrations {
    static let claudeDesktopBundleID = "com.anthropic.claudefordesktop"

    /// CLI incluida en la app (ruta estable de /Applications si existe).
    static var cliPath: String {
        let current = Bundle.main.resourceURL?.appendingPathComponent("splitexercises").path ?? "/Applications/SplitExercises.app/Contents/Resources/splitexercises"
        return ClaudeSkill.stableCLIPath(current: current)
    }

    static var claudeDesktopURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeDesktopBundleID)
            ?? (FileManager.default.fileExists(atPath: "/Applications/Claude.app") ? URL(fileURLWithPath: "/Applications/Claude.app") : nil)
    }

    /// Cierra la app de Claude y la vuelve a abrir (espera a que termine de cerrarse) para que cargue la herramienta nueva.
    /// Si no estaba abierta no hace nada: la cargará la próxima vez.
    static func restartClaude() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: claudeDesktopBundleID)
        guard !running.isEmpty else { return }
        running.forEach { $0.terminate() }
        var tries = 0
        func reopen() {
            let stillOpen = !NSRunningApplication.runningApplications(withBundleIdentifier: claudeDesktopBundleID).isEmpty
            if stillOpen, tries < 20 { tries += 1; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: reopen); return }
            if let u = claudeDesktopURL { NSWorkspace.shared.openApplication(at: u, configuration: NSWorkspace.OpenConfiguration()) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: reopen)
    }

    /// Un solo paso: instala el skill y la herramienta, y reinicia Claude si estaba abierta. Devuelve el estado y si se reinició.
    static func installClaude() throws -> (status: ClaudeStatus, restarted: Bool) {
        let wasRunning = claudeRunning
        let st = try ClaudeSetup.connect(cliPath: cliPath)
        let restart = st.desktop && wasRunning
        if restart { restartClaude() }
        return (st, restart)
    }
    static var claudeRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: claudeDesktopBundleID).isEmpty }
}

/// Naranja de Claude.
let claudeOrange = Color(red: 0.851, green: 0.467, blue: 0.341)

enum ClaudePhase {
    case idle
    case done(ClaudeStatus, restarted: Bool)
    case failed(String)
}

/// Tercera forma de usar SplitExercises: pedírselo a Claude. Toda la tarjeta es el botón: un clic lo instala y reinicia Claude.
struct ClaudeConnectCard: View {
    @StateObject private var phase = Local<ClaudePhase>({ let st = ClaudeSetup.status(); return st.anyConnected ? .done(st, restarted: false) : .idle }())

    private var connected: Bool { if case .done = phase.v { return true } else { return false } }

    private func install() {
        if connected { return }
        do { let r = try Integrations.installClaude(); phase.v = .done(r.status, restarted: r.restarted) }
        catch { phase.v = .failed(error.localizedDescription) }
    }

    var body: some View {
        Button(action: install) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: connected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 17)).foregroundStyle(connected ? claudeOrange : Color.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Con Claude", "With Claude")).font(.system(size: 13, weight: .semibold))
                        Text(connected ? tr("Instalado", "Installed") : tr("Nuevo", "New")).font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(claudeOrange.opacity(connected ? 1 : 0.85))).foregroundStyle(Color.white)
                    }
                    Spacer(minLength: 0)
                }
                ClaudeChatMock().frame(maxWidth: .infinity, minHeight: 130, maxHeight: 130, alignment: .top)
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Claude entiende lo que quieres: cuando pidas dividir un PDF en ejercicios —«separa los ejercicios de este PDF», «un ejercicio por hoja», «divide todos los de la carpeta Tema 3»— usará SplitExercises con tus ajustes, en lote o directamente desde la conversación.",
                            "Claude gets what you mean: when you ask to split a PDF into exercises — “separate the exercises in this PDF”, “one exercise per sheet”, “split everything in the Unit 3 folder” — it uses SplitExercises with your settings, in batch or right from the chat."))
                    Text(tr("Se ocupa de detectar qué archivos son ejercicios y deja intactos los demás.",
                            "It works out which files are exercises and leaves the rest untouched."))
                        .fontWeight(.medium).foregroundStyle(.primary)
                }
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(claudeOrange.opacity(connected ? 0.16 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(claudeOrange.opacity(connected ? 1 : 0.7), style: StrokeStyle(lineWidth: connected ? 2 : 1.2, dash: connected ? [] : [5, 4])))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var content: some View {
        switch phase.v {
        case .idle:
            VStack(alignment: .leading, spacing: 5) {
                Label(tr("Instalar para Claude", "Install for Claude"), systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(Capsule().fill(claudeOrange))
                if Integrations.claudeRunning {
                    Text(tr("Un clic y listo: se reinicia Claude para activarlo.", "One click and done: Claude restarts to activate it."))
                        .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        case .failed(let msg):
            Text(msg).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            Text(tr("Haz clic para reintentar.", "Click to try again.")).font(.caption).foregroundStyle(claudeOrange)
        case .done(let c, let restarted):
            VStack(alignment: .leading, spacing: 4) {
                if c.claudeCode {
                    Label(tr("Claude Code: listo", "Claude Code: ready"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(claudeOrange)
                }
                if c.desktop {
                    Label(restarted ? tr("App de Claude: conectada, reiniciándose…", "Claude app: connected, restarting…")
                                    : tr("App de Claude: conectada", "Claude app: connected"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(claudeOrange)
                    if !restarted && Integrations.claudeRunning {
                        Text(tr("Reinicia Claude para activarla.", "Restart Claude to activate it.")).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                } else if let e = c.desktopError {
                    Text(e).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                } else if !c.desktopInstalled {
                    Text(tr("No encuentro la app de Claude; solo Claude Code.", "I can't find the Claude app; Claude Code only."))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Maqueta de una conversación con Claude usando SplitExercises.
struct ClaudeChatMock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer(minLength: 24)
                Text(tr("Separa los ejercicios de esta carpeta", "Split the exercises in this folder"))
                    .font(.system(size: 10)).padding(.horizontal, 9).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(claudeOrange.opacity(0.35)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("$ splitexercises split ~/Tema3").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                Text(tr("✓ 8 divididos · 3 omitidos", "✓ 8 split · 3 skipped")).font(.system(size: 10, weight: .medium))
            }
            .padding(9).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.gray.opacity(0.16)))
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
    }
}
