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

    /// Cierra y vuelve a abrir la app de Claude para que cargue la herramienta nueva.
    static func restartClaude() {
        NSRunningApplication.runningApplications(withBundleIdentifier: claudeDesktopBundleID).forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let u = claudeDesktopURL { NSWorkspace.shared.openApplication(at: u, configuration: NSWorkspace.OpenConfiguration()) }
        }
    }
    static var claudeRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: claudeDesktopBundleID).isEmpty }
}

/// Naranja de Claude.
let claudeOrange = Color(red: 0.851, green: 0.467, blue: 0.341)

enum ClaudePhase {
    case idle
    case done(ClaudeStatus)
    case failed(String)
}

/// Tercera forma de usar SplitExercises: pedírselo a Claude. Un botón la deja lista.
struct ClaudeConnectCard: View {
    @StateObject private var phase = Local<ClaudePhase>({ let st = ClaudeSetup.status(); return st.anyConnected ? .done(st) : .idle }())

    private func connect() {
        do { phase.v = .done(try ClaudeSetup.connect(cliPath: Integrations.cliPath)) } catch { phase.v = .failed(error.localizedDescription) }
    }

    var body: some View {
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
            ClaudeChatMock().frame(maxWidth: .infinity, minHeight: 190, maxHeight: 190, alignment: .top)
            Text(tr("En la app de Claude (chat y Cowork) o en Claude Code, pídele «divide los ejercicios de esta carpeta». Usa tus ajustes.",
                    "In the Claude app (chat and Cowork) or Claude Code, ask “split the exercises in this folder”. It uses your settings."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            content
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(claudeOrange.opacity(connected ? 0.16 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(claudeOrange.opacity(connected ? 1 : 0.7), style: StrokeStyle(lineWidth: connected ? 2 : 1.2, dash: connected ? [] : [5, 4])))
    }

    private var connected: Bool { if case .done = phase.v { return true } else { return false } }

    @ViewBuilder private var content: some View {
        switch phase.v {
        case .idle:
            Button(action: connect) {
                Label(tr("Instalar para Claude", "Install for Claude"), systemImage: "arrow.down.circle.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(claudeOrange).controlSize(.regular)
        case .failed(let msg):
            Text(msg).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            Button(tr("Reintentar", "Try again"), action: connect).tint(claudeOrange)
        case .done(let c):
            VStack(alignment: .leading, spacing: 6) {
                if c.claudeCode {
                    Label(tr("Claude Code: listo", "Claude Code: ready"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(claudeOrange)
                }
                if c.desktop {
                    Label(tr("App de Claude: conectada", "Claude app: connected"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(claudeOrange)
                    Text(Integrations.claudeRunning
                         ? tr("Reinicia Claude para que cargue la herramienta.", "Restart Claude so it loads the tool.")
                         : tr("Se activará la próxima vez que abras Claude.", "It will be active the next time you open Claude."))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if Integrations.claudeRunning {
                        Button(tr("Reiniciar Claude ahora", "Restart Claude now")) { Integrations.restartClaude() }.controlSize(.small)
                    }
                } else if let e = c.desktopError {
                    Text(e).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                } else if !c.desktopInstalled {
                    Text(tr("No encuentro la app de Claude. Si la instalas, vuelve a abrir esta pantalla desde Ajustes.", "I can't find the Claude app. If you install it, connect again from Settings."))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
                Text(tr("Divide los ejercicios de esta carpeta", "Split the exercises in this folder"))
                    .font(.system(size: 10)).padding(.horizontal, 9).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(claudeOrange.opacity(0.35)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("$ splitexercises split ~/Tema3").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                Text(tr("✓ 8 divididos · 3 omitidos", "✓ 8 split · 3 skipped")).font(.system(size: 10, weight: .medium))
                Text(tr("Cada ejercicio en su hoja, con tus ajustes. Los que no eran ejercicios, intactos.",
                        "Each exercise on its own sheet, with your settings. Non-exercise PDFs untouched."))
                    .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
