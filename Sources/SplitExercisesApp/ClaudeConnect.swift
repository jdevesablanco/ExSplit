import SwiftUI
import AppKit
import SplitExercisesCore

/// Conexión con Claude: instala el skill que enseña a Claude a usar la CLI de SplitExercises.
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

    struct ClaudeConnection {
        var claudeCode: Bool
        var desktopInstalled: Bool
        var zip: URL?
    }

    static var zipFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SplitExercises", isDirectory: true)
    }

    /// Un clic: deja el skill listo en Claude Code y, si está la app de Claude, prepara el .zip que ésta necesita.
    static func connectClaude() throws -> ClaudeConnection {
        try ClaudeSkill.installForClaudeCode(cliPath: cliPath)
        let desktop = claudeDesktopURL != nil
        let zip = desktop ? (try? ClaudeSkill.exportZip(to: zipFolder, cliPath: cliPath)) : nil
        return ClaudeConnection(claudeCode: true, desktopInstalled: desktop, zip: zip)
    }

    /// Estado al abrir la pantalla: si el skill ya está en Claude Code se muestra como conectado.
    static func currentClaudeConnection() -> ClaudeConnection? {
        guard ClaudeSkill.installedInClaudeCode else { return nil }
        let zip = zipFolder.appendingPathComponent("SplitExercises-skill.zip")
        return ClaudeConnection(claudeCode: true, desktopInstalled: claudeDesktopURL != nil,
                                zip: FileManager.default.fileExists(atPath: zip.path) ? zip : nil)
    }

    static func disconnectClaude() {
        ClaudeSkill.uninstallFromClaudeCode()
        try? FileManager.default.removeItem(at: zipFolder.appendingPathComponent("SplitExercises-skill.zip"))
    }

    static func revealSkillZip(_ zip: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([zip])
        if let app = claudeDesktopURL { NSWorkspace.shared.open(app) }
    }
}

enum ClaudePhase {
    case idle
    case done(Integrations.ClaudeConnection)
    case failed(String)
}

/// Tercera forma de usar SplitExercises: pedírselo a Claude. Un botón la deja lista.
struct ClaudeConnectCard: View {
    @StateObject private var phase = Local<ClaudePhase>(Integrations.currentClaudeConnection().map { .done($0) } ?? .idle)

    private func connect() {
        do { phase.v = .done(try Integrations.connectClaude()) } catch { phase.v = .failed(error.localizedDescription) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 17)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Con Claude", "With Claude")).font(.system(size: 13, weight: .semibold))
                    Text(tr("Nuevo", "New")).font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.85))).foregroundStyle(Color.white)
                }
                Spacer(minLength: 0)
            }
            ClaudeChatMock().frame(maxWidth: .infinity, minHeight: 190, maxHeight: 190, alignment: .top)
            Text(tr("Pídele «divide los ejercicios de esta carpeta». Claude sabrá qué PDFs son ejercicios y usará tus ajustes.",
                    "Ask “split the exercises in this folder”. Claude will find the exercise PDFs and use your settings."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            content
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.accentColor.opacity(0.8), lineWidth: 1))
    }

    @ViewBuilder private var content: some View {
        switch phase.v {
        case .idle:
            Button(action: connect) {
                Label(tr("Conectar con Claude", "Connect to Claude"), systemImage: "link").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.regular)
        case .failed(let msg):
            Text(msg).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            Button(tr("Reintentar", "Try again"), action: connect)
        case .done(let c):
            VStack(alignment: .leading, spacing: 6) {
                Label(tr("Claude Code: listo", "Claude Code: ready"), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color.green)
                if c.desktopInstalled, let zip = c.zip {
                    Text(tr("App de Claude: sube el skill una vez (Ajustes → Capacidades → Skills → Subir skill).",
                            "Claude app: upload the skill once (Settings → Capabilities → Skills → Upload skill)."))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(tr("Mostrar el .zip y abrir Claude", "Show the .zip and open Claude")) { Integrations.revealSkillZip(zip) }
                        .controlSize(.small)
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
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.accentColor.opacity(0.28)))
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
