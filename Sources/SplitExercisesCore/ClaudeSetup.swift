import Foundation

public struct ClaudeStatus {
    /// Skill instalado para Claude Code (`~/.claude/skills`).
    public var claudeCode = false
    /// Servidor MCP registrado en la app de Claude (chat y Cowork).
    public var desktop = false
    public var desktopInstalled = false
    public var desktopError: String?
    public var anyConnected: Bool { claudeCode || desktop }
}

enum ClaudeSetupError: LocalizedError {
    case invalidConfig(String)
    var errorDescription: String? {
        switch self {
        case .invalidConfig(let p):
            return tr("No he tocado \(p): no es un JSON válido. Revísalo o añade «splitexercises» a mano.",
                      "I left \(p) alone: it isn't valid JSON. Fix it or add “splitexercises” by hand.")
        }
    }
}

/// App de Claude (chat y Cowork): se conecta registrando `splitexercises mcp` en su `claude_desktop_config.json`.
public enum ClaudeDesktop {
    public static let serverName = "splitexercises"

    public static var configURL: URL {
        if let o = ProcessInfo.processInfo.environment["SPLITEXERCISES_CLAUDE_CONFIG"], !o.isEmpty { return URL(fileURLWithPath: o) }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
    }
    public static var installed: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: "/Applications/Claude.app") || fm.fileExists(atPath: configURL.deletingLastPathComponent().path)
    }

    static func load() throws -> [String: Any] {
        guard let d = try? Data(contentsOf: configURL) else { return [:] }
        if d.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { throw ClaudeSetupError.invalidConfig(configURL.path) }
        return o
    }

    static func save(_ cfg: [String: Any]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = configURL.deletingLastPathComponent().appendingPathComponent(configURL.lastPathComponent + ".splitexercises-backup")
        if fm.fileExists(atPath: configURL.path), !fm.fileExists(atPath: backup.path) { try? fm.copyItem(at: configURL, to: backup) }
        let d = try JSONSerialization.data(withJSONObject: cfg, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try d.write(to: configURL, options: .atomic)
    }

    public static var isConnected: Bool {
        ((try? load())?["mcpServers"] as? [String: Any])?[serverName] != nil
    }

    public static func connect(cliPath: String) throws {
        var cfg = try load()
        var servers = cfg["mcpServers"] as? [String: Any] ?? [:]
        servers[serverName] = ["command": cliPath, "args": ["mcp"]]
        cfg["mcpServers"] = servers
        try save(cfg)
    }

    public static func disconnect() throws {
        var cfg = try load()
        guard var servers = cfg["mcpServers"] as? [String: Any], servers[serverName] != nil else { return }
        servers.removeValue(forKey: serverName)
        if servers.isEmpty { cfg.removeValue(forKey: "mcpServers") } else { cfg["mcpServers"] = servers }
        try save(cfg)
    }
}

/// Conecta SplitExercises con Claude en un paso: skill para Claude Code + servidor MCP para la app de Claude.
public enum ClaudeSetup {
    public static func status() -> ClaudeStatus {
        ClaudeStatus(claudeCode: ClaudeSkill.installedInClaudeCode, desktop: ClaudeDesktop.isConnected, desktopInstalled: ClaudeDesktop.installed)
    }

    public static func connect(cliPath: String) throws -> ClaudeStatus {
        try ClaudeSkill.installForClaudeCode(cliPath: cliPath)
        var st = status()
        if st.desktopInstalled {
            do { try ClaudeDesktop.connect(cliPath: cliPath) } catch { st.desktopError = error.localizedDescription }
            st.desktop = ClaudeDesktop.isConnected
        }
        return st
    }

    public static func disconnect() {
        ClaudeSkill.uninstallFromClaudeCode()
        try? ClaudeDesktop.disconnect()
    }
}
