import AppKit
import ServiceManagement
import SplitExercisesCore

/// Todo lo que engancha la app con macOS: Acción rápida, extensión de Finder, inicio de sesión.
enum Integrations {
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "io.github.jdevesablanco.SplitExercises" }
    static var appURL: URL { Bundle.main.bundleURL }

    // MARK: Acción rápida (aparece en «Acciones rápidas» y en «Servicios»)

    static var workflowURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services/\(tr("SplitExercises", "SplitExercises")).workflow", isDirectory: true)
    }
    static var quickActionInstalled: Bool {
        FileManager.default.fileExists(atPath: workflowURL.path) || (rightYourClickInstalled && FileManager.default.fileExists(atPath: rycActionURL.path))
    }

    // MARK: RightYourClick (menú de clic derecho compartido del pack)
    // Si está instalada, SplitExercises no crea su propia Acción rápida: declara la acción en el registro de RightYourClick,
    // que genera y mantiene la Acción rápida (y la lista en su selector). Si no, SplitExercises sigue con la suya.

    static let rycBundleID = "com.jdevesablanco.rightyourclick"
    /// Solo cede la Acción rápida a RightYourClick cuando está publicada (mientras sea «Próximamente», SplitExercises va por su cuenta).
    static var rightYourClickReleased: Bool { PackCatalog.apps.first { $0.id == rycBundleID }?.released ?? false }
    static var rightYourClickInstalled: Bool {
        rightYourClickReleased
            && NSWorkspace.shared.urlForApplication(withBundleIdentifier: rycBundleID) != nil
    }
    static var rycActionURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RightYourClick/actions/\(bundleID).split.json")
    }

    static func registerWithRightYourClick() throws {
        let spec: [String: Any] = [
            "schema": 1,
            "id": "\(bundleID).split",
            "title": ["en": "SplitExercises", "es": "SplitExercises"],
            "symbol": "rectangle.split.1x2",
            "fileTypes": ["com.adobe.pdf"],
            "bundleID": bundleID,
            "owner": "SplitExercises",
            // nuestra Acción rápida propia: RightYourClick la retira para que no salga dos veces
            "replaces": ["Split exercises with ExSplit", "Dividir ejercicios con ExSplit", "Split exercises with SplitExercises", "Dividir ejercicios con SplitExercises"],
        ]
        try FileManager.default.createDirectory(at: rycActionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let d = try JSONSerialization.data(withJSONObject: spec, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try d.write(to: rycActionURL, options: .atomic)
        pingRightYourClick()
    }

    /// RightYourClick relee el registro y regenera las Acciones rápidas (en segundo plano, sin ventanas).
    static func pingRightYourClick() {
        guard rightYourClickInstalled, let u = URL(string: "rightyourclick://sync") else { return }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = false
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rycBundleID) {
            NSWorkspace.shared.open([u], withApplicationAt: app, configuration: cfg)
        }
    }

    /// Versiones anteriores llamaban a la acción «Dividir ejercicios con …». Si queda alguna, se retira y se reinstala con el nombre actual.
    static func migrateLegacyQuickAction() {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services", isDirectory: true)
        let legacy = ["Dividir ejercicios con SplitExercises", "Split exercises with SplitExercises",
                      "Dividir ejercicios con ExSplit", "Split exercises with ExSplit"]
        var found = false
        for name in legacy {
            let u = dir.appendingPathComponent("\(name).workflow", isDirectory: true)
            if fm.fileExists(atPath: u.path) { try? fm.removeItem(at: u); found = true }
        }
        if found || (fm.fileExists(atPath: rycActionURL.path) && ((try? String(contentsOf: rycActionURL, encoding: .utf8))?.contains("Dividir ejercicios con") ?? false)) {
            try? installQuickAction()
            refreshServices()
        }
    }

    static func installQuickAction() throws {
        // Siempre se declara en el registro (si RightYourClick llega después, la recoge sola).
        if rightYourClickReleased { try? registerWithRightYourClick() }
        if rightYourClickInstalled { return }
        let fm = FileManager.default
        let contents = workflowURL.appendingPathComponent("Contents", isDirectory: true)
        try? fm.removeItem(at: workflowURL)
        try fm.createDirectory(at: contents, withIntermediateDirectories: true)
        let title = tr("SplitExercises", "SplitExercises")

        let info: [String: Any] = [
            "NSServices": [[
                "NSBackgroundColorName": "background",
                "NSIconName": "SplitExercisesTemplate",
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
        // Icono propio (círculo + símbolo de SplitExercises, como el resto de acciones). El sufijo «Template» lo hace icono de plantilla:
        // macOS lo tiñe igual que los demás en claro y oscuro.
        let res = contents.appendingPathComponent("Resources", isDirectory: true)
        try fm.createDirectory(at: res, withIntermediateDirectories: true)
        try quickActionIcon(size: 64).write(to: res.appendingPathComponent("SplitExercisesTemplate.png"))
        try quickActionIcon(size: 128).write(to: res.appendingPathComponent("SplitExercisesTemplate@2x.png"))
        refreshServices()
        enableQuickActionInFinder()
    }

    /// macOS ≥ 15 deja las Acciones rápidas nuevas DESACTIVADAS (Ajustes → Extensiones → Finder). Las activamos
    /// escribiendo la misma entrada que crea el interruptor de Ajustes del Sistema.
    static func enableQuickActionInFinder() {
        let title = tr("SplitExercises", "SplitExercises")
        let key = "(null) - \(title) - runWorkflowAsService"
        let domain = "pbs" as CFString
        var all = (CFPreferencesCopyAppValue("NSServicesStatus" as CFString, domain) as? [String: Any]) ?? [:]
        all[key] = ["presentation_modes": ["ContextMenu": 1, "FinderPreview": 1, "ServicesMenu": 1, "TouchBar": 0]]
        CFPreferencesSetAppValue("NSServicesStatus" as CFString, all as CFDictionary, domain)
        CFPreferencesAppSynchronize(domain)
        refreshServices()
    }

    /// PNG negro sobre transparente: círculo con el símbolo de SplitExercises.
    static func quickActionIcon(size: CGFloat) throws -> Data {
        let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .regular)
        guard let sym = NSImage(systemSymbolName: "rectangle.split.1x2", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        let lw = size * 0.075, inset = size * 0.04
        let ring = NSBezierPath(ovalIn: NSRect(x: lw / 2 + inset, y: lw / 2 + inset, width: size - lw - inset * 2, height: size - lw - inset * 2))
        ring.lineWidth = lw
        NSColor.black.setStroke()
        ring.stroke()
        let s = sym.size
        let r = NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height)
        sym.draw(in: r)
        NSColor.black.set()
        r.fill(using: .sourceAtop)
        img.unlockFocus()
        guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return png
    }

    static func removeQuickAction() {
        try? FileManager.default.removeItem(at: workflowURL)
        try? FileManager.default.removeItem(at: rycActionURL)
        pingRightYourClick()
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
