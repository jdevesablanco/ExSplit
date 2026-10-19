import Cocoa
import FinderSync

/// Extensión de Finder: añade «Dividir ejercicios» directamente al menú contextual de los PDFs.
/// No procesa nada ella misma (está en sandbox): le pasa los archivos a la app por el esquema `exsplit://`.
final class FinderSync: FIFinderSync {
    override init() {
        super.init()
        // Carpeta personal real (en el sandbox NSHomeDirectory() apunta al contenedor) y discos externos.
        var dirs: [URL] = [URL(fileURLWithPath: "/Volumes")]
        if let pw = getpwuid(getuid()), let d = pw.pointee.pw_dir { dirs.append(URL(fileURLWithPath: String(cString: d))) }
        FIFinderSyncController.default().directoryURLs = Set(dirs)
    }

    private func tr(_ es: String, _ en: String) -> String {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("es") ? es : en
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        let urls = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard !urls.isEmpty, urls.allSatisfy({ $0.pathExtension.lowercased() == "pdf" }) else { return nil }
        let menu = NSMenu(title: "")
        let split = NSMenuItem(title: tr("Dividir ejercicios (ExSplit)", "Split exercises (ExSplit)"), action: #selector(splitAction(_:)), keyEquivalent: "")
        split.image = NSImage(systemSymbolName: "rectangle.split.1x2", accessibilityDescription: nil)
        split.target = self
        menu.addItem(split)
        let settings = NSMenuItem(title: tr("Ajustes de ExSplit…", "ExSplit settings…"), action: #selector(settingsAction(_:)), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        return menu
    }

    @objc func splitAction(_ sender: Any?) {
        let urls = FIFinderSyncController.default().selectedItemURLs() ?? []
        var c = URLComponents()
        c.scheme = "exsplit"; c.host = "split"
        c.queryItems = urls.map { URLQueryItem(name: "path", value: $0.path) }
        if let u = c.url { NSWorkspace.shared.open(u) }
    }

    @objc func settingsAction(_ sender: Any?) {
        if let u = URL(string: "exsplit://settings") { NSWorkspace.shared.open(u) }
    }
}
