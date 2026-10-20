import Foundation

/// Servidor MCP mínimo (JSON-RPC 2.0 por stdio, un mensaje por línea) para que la app de Claude (chat y Cowork) y cualquier cliente MCP
/// usen SplitExercises como herramienta. Las herramientas aplican los ajustes guardados del usuario: el cliente no elige opciones.
public enum MCPServer {
    static let version = "1.1.0"

    static let pathsSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "paths": ["type": "array", "items": ["type": "string"],
                      "description": "Absolute paths of PDF files and/or folders (use ~ for the home folder)."],
            "recursive": ["type": "boolean", "description": "Include subfolders when a folder is given. Default false."],
        ],
        "required": ["paths"],
    ]

    static var tools: [[String: Any]] {
        [
            ["name": "split_exercises",
             "description": "Split exercise PDFs into one exercise per sheet with the SplitExercises app, applying the user's saved settings (paper, label, answer area, what happens to the original, file naming). Accepts PDF files and/or folders. In a folder it decides by itself which PDFs are exercise sheets and skips the rest (non-exercise PDFs, earlier results, the originals folder). Do not move, rename or edit files yourself and do not ask for options: the saved settings are used. Returns JSON with one entry per file (status split / skipped / failed).",
             "inputSchema": pathsSchema],
            ["name": "analyze_exercises",
             "description": "Read-only preview: counts the exercises in PDFs or folders and says which PDFs split_exercises would process. Changes nothing.",
             "inputSchema": pathsSchema,
             "annotations": ["readOnlyHint": true]],
            ["name": "undo_last_split",
             "description": "Undo the last split: restores the original PDF and sends the result to the Trash.",
             "inputSchema": ["type": "object", "properties": [String: Any]()]],
        ]
    }

    public static func run() {
        while let line = readLine(strippingNewline: true) {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, let d = t.data(using: .utf8),
                  let msg = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { continue }
            handle(msg)
        }
    }

    static func send(_ obj: [String: Any]) {
        guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.withoutEscapingSlashes]) else { return }
        FileHandle.standardOutput.write(d + Data("\n".utf8))
    }

    static func handle(_ msg: [String: Any]) {
        guard let method = msg["method"] as? String else { return }   // respuestas del cliente: se ignoran
        let id = msg["id"]
        func ok(_ result: [String: Any]) { if let id { send(["jsonrpc": "2.0", "id": id, "result": result]) } }
        func fail(_ code: Int, _ text: String) { if let id { send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": text]]) } }
        let params = msg["params"] as? [String: Any] ?? [:]
        switch method {
        case "initialize":
            ok(["protocolVersion": (params["protocolVersion"] as? String) ?? "2025-06-18",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "splitexercises", "version": version]])
        case "ping": ok([:])
        case "tools/list": ok(["tools": tools])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let args = params["arguments"] as? [String: Any] ?? [:]
            guard tools.contains(where: { $0["name"] as? String == name }) else { fail(-32602, "Unknown tool: \(name)"); return }
            let (text, isError) = call(name, args)
            ok(["content": [["type": "text", "text": text]], "isError": isError])
        default:
            if id != nil { fail(-32601, "Method not found: \(method)") }   // las notificaciones (sin id) no se responden
        }
    }

    static func call(_ name: String, _ args: [String: Any]) -> (String, Bool) {
        let s = SettingsStore.load()
        Lang.forced = s.language
        var paths: [String] = []
        if let a = args["paths"] as? [String] { paths = a } else if let one = args["paths"] as? String { paths = [one] }
        let recursive = args["recursive"] as? Bool ?? false
        switch name {
        case "split_exercises", "analyze_exercises":
            guard !paths.isEmpty else { return ("`paths` is required: absolute paths of PDFs and/or folders.", true) }
            let entries = name == "split_exercises" ? Batch.split(paths, recursive: recursive, settings: s)
                                                    : Batch.analyze(paths, recursive: recursive, settings: s)
            return (Batch.json(entries), entries.count > 0 && entries.allSatisfy { $0.status == .failed })
        default: // undo_last_split
            do { let e = try Splitter.undo(); return ("Undone: \(e.originalHome) restored.", false) }
            catch { return (error.localizedDescription, true) }
        }
    }
}
