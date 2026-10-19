import AppKit
import ServiceManagement
import ExSplitCore

/// Todo lo que engancha la app con macOS: Acción rápida, extensión de Finder, inicio de sesión.
enum Integrations {
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "io.github.jdevesablanco.ExSplit" }
    static var finderExtensionID: String { bundleID + ".FinderExtension" }
    static var appURL: URL { Bundle.main.bundleURL }

    // MARK: Acción rápida (aparece en «Acciones rápidas» y en «Servicios»)

    static var workflowURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services/\(tr("Dividir ejercicios con ExSplit", "Split exercises with ExSplit")).workflow", isDirectory: true)
    }
    static var quickActionInstalled: Bool { FileManager.default.fileExists(atPath: workflowURL.path) }

    static func installQuickAction() throws {
        let fm = FileManager.default
        let contents = workflowURL.appendingPathComponent("Contents", isDirectory: true)
        try? fm.removeItem(at: workflowURL)
        try fm.createDirectory(at: contents, withIntermediateDirectories: true)
        let title = tr("Dividir ejercicios con ExSplit", "Split exercises with ExSplit")

        let info: [String: Any] = [
            "NSServices": [[
                "NSBackgroundColorName": "background",
                "NSIconName": "NSActionTemplate",
                "NSMenuItem": ["default": title],
                "NSMessage": "runWorkflowAsService",
                "NSRequiredContext": ["NSApplicationIdentifier": "com.apple.finder"],
                "NSSendFileTypes": ["com.adobe.pdf"],
            ]]
        ]
        // Pasa los archivos a la app (la app respeta ⌥ y los ajustes). `open -b` localiza la app dónde esté instalada.
        let script = "/usr/bin/open -b \(bundleID) \"$@\""
        let action: [String: Any] = [
            "AMAccepts": ["Container": "List", "Optional": true, "Types": ["com.apple.cocoa.string"]],
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMParameterProperties": ["COMMAND_STRING": [:], "CheckedForUserDefaultShell": [:], "inputMethod": [:], "shell": [:], "source": [:]],
            "AMProvides": ["Container": "List", "Types": ["com.apple.cocoa.string"]],
            "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
            "ActionName": "Run Shell Script",
            "ActionParameters": ["COMMAND_STRING": script, "CheckedForUserDefaultShell": true, "inputMethod": 1, "shell": "/bin/zsh", "source": ""],
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": false,
            "CanShowWhenRun": true,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": UUID().uuidString,
            "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
            "OutputUUID": UUID().uuidString,
            "UUID": UUID().uuidString,
            "UnlocalizedApplications": ["Automator"],
            "arguments": [String: Any](),
            "isViewVisible": 1,
            "location": "309.000000:305.000000",
            "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
        ]
        let wflow: [String: Any] = [
            "AMApplicationBuild": "523",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [["action": action, "isViewVisible": 1]],
            "connectors": [String: Any](),
            "workflowMetaData": [
                "applicationBundleIDsByPath": [String: Any](),
                "applicationPaths": [String](),
                "inputTypeIdentifier": "com.apple.Automator.fileSystemObject",
                "outputTypeIdentifier": "com.apple.Automator.nothing",
                "presentationMode": 15,
                "processesInput": 0,
                "serviceApplicationBundleID": "com.apple.finder",
                "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
                "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
                "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
                "serviceProcessesInput": 0,
                "systemImageName": "NSActionTemplate",
                "useAutomaticInputType": 0,
                "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
            ],
        ]
        try write(plist: info, to: contents.appendingPathComponent("Info.plist"))
        try write(plist: wflow, to: contents.appendingPathComponent("document.wflow"))
        refreshServices()
        enableQuickActionInFinder()
    }

    /// macOS ≥ 15 deja las Acciones rápidas nuevas DESACTIVADAS (Ajustes → Extensiones → Finder). Las activamos
    /// escribiendo la misma entrada que crea el interruptor de Ajustes del Sistema.
    static func enableQuickActionInFinder() {
        let title = tr("Dividir ejercicios con ExSplit", "Split exercises with ExSplit")
        let key = "(null) - \(title) - runWorkflowAsService"
        let domain = "pbs" as CFString
        var all = (CFPreferencesCopyAppValue("NSServicesStatus" as CFString, domain) as? [String: Any]) ?? [:]
        all[key] = ["presentation_modes": ["ContextMenu": 1, "FinderPreview": 1, "ServicesMenu": 1, "TouchBar": 0]]
        CFPreferencesSetAppValue("NSServicesStatus" as CFString, all as CFDictionary, domain)
        CFPreferencesAppSynchronize(domain)
        refreshServices()
    }

    static func removeQuickAction() {
        try? FileManager.default.removeItem(at: workflowURL)
        refreshServices()
    }

    private static func write(plist: [String: Any], to url: URL) throws {
        let d = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try d.write(to: url)
    }

    static func refreshServices() {
        NSUpdateDynamicServices()
        run("/System/Library/CoreServices/pbs", ["-update"])
    }

    // MARK: Extensión de Finder (opción directa en el menú contextual)

    static var finderExtensionPath: URL { appURL.appendingPathComponent("Contents/PlugIns/ExSplitFinder.appex") }
    static var finderExtensionBundled: Bool { FileManager.default.fileExists(atPath: finderExtensionPath.path) }

    static func finderExtensionEnabled() -> Bool {
        let out = run("/usr/bin/pluginkit", ["-m", "-i", finderExtensionID])
        return out.split(separator: "\n").contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("+") }
    }

    /// Registra y activa la extensión (sin reiniciar Finder). Si macOS no la deja activar sola, abre Ajustes del Sistema.
    static func enableFinderExtension(completion: @escaping (Bool) -> Void) {
        guard finderExtensionBundled else { completion(false); return }
        DispatchQueue.global(qos: .userInitiated).async {
            run("/usr/bin/pluginkit", ["-a", finderExtensionPath.path])
            Thread.sleep(forTimeInterval: 1.0)   // pluginkit necesita un instante para dar de alta el plug-in
            run("/usr/bin/pluginkit", ["-e", "use", "-i", finderExtensionID])
            Thread.sleep(forTimeInterval: 1.0)
            let ok = finderExtensionEnabled()
            DispatchQueue.main.async {
                if !ok { openExtensionSettings() }
                completion(ok)
            }
        }
    }

    static func disableFinderExtension() {
        run("/usr/bin/pluginkit", ["-e", "ignore", "-i", finderExtensionID])
    }

    static func openExtensionSettings() {
        for u in ["x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.FinderSync",
                  "x-apple.systempreferences:com.apple.ExtensionsPreferences"] {
            if let url = URL(string: u), NSWorkspace.shared.open(url) { return }
        }
    }

    // MARK: inicio de sesión

    static func setLaunchAtLogin(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch { return error.localizedDescription }
    }
    static var launchAtLoginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    // MARK: util

    @discardableResult
    static func run(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return "" }
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: d, encoding: .utf8) ?? ""
    }
}
