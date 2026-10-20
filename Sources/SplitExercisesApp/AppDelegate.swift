import AppKit
import SwiftUI
import CoreServices
import UniformTypeIdentifiers
import SplitExercisesCore

final class ActionItem: NSMenuItem {
    var handler: (() -> Void)?
    convenience init(_ title: String, key: String = "", checked: Bool = false, enabled: Bool = true, _ h: @escaping () -> Void) {
        self.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self; handler = h; state = checked ? .on : .off; isEnabled = enabled
    }
    @objc func fire() { handler?() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let model = SettingsModel.shared
    let toast = ToastController()
    let services = ServiceProvider()
    var statusItem: NSStatusItem?
    var backdropWindow: NSWindow?   // dev: fondo limpio para capturas
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    var runWindow: NSWindow?
    var pending: [URL] = []
    var busy = 0
    var openedForFiles = false

    // MARK: ciclo de vida

    func applicationWillFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = MainMenu.build(target: self)
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        Integrations.migrateLegacyQuickAction()
        PackCatalog.isSpanish = { tr("es", "en") == "es" }
        if let dir = ProcessInfo.processInfo.environment["SPLITEXERCISES_SNAPSHOT"] { Snapshot.run(model: model, dir: dir); NSApp.terminate(nil); return }
        Lang.forced = model.s.language
        if let shot = ProcessInfo.processInfo.environment["SPLITEXERCISES_SHOT"] { captureWindow(spec: shot); return }
        let defaultLaunch = (n.userInfo?["NSApplicationLaunchIsDefaultLaunchKey"] as? Bool) ?? true
        let loginLaunch = launchedAsLoginItem()
        NSApp.servicesProvider = services
        services.delegate = self
        NSUpdateDynamicServices()
        toast.onHidden = { [weak self] in self?.maybeQuit() }
        model.onChange = { [weak self] old, new in self?.settingsChanged(old, new) }
        refreshStatusItem()

        // Si se lanzó para abrir archivos (clic derecho, Servicios…) llegarán en application(_:open:); si no, es el usuario abriendo la app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            if !model.s.onboardingDone {
                if onboardingWindow == nil { showOnboarding() }
            } else if defaultLaunch && !loginLaunch && !openedForFiles && pending.isEmpty && busy == 0 {
                showSettings()
            }
            maybeQuit()
        }
    }

    func launchedAsLoginItem() -> Bool {
        guard let ev = NSAppleEventManager.shared().currentAppleEvent,
              ev.eventID == AEEventID(kAEOpenApplication),
              let d = ev.paramDescriptor(forKeyword: AEKeyword(keyAEPropData)) else { return false }
        return d.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        openedForFiles = true
        handle(urls)
    }

    /// Reabrir la app (Spotlight, Launchpad, Finder) = vía discreta para tocar los ajustes aunque no haya icono en la barra.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model.s.onboardingDone { showSettings() } else { showOnboarding() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: entrada de archivos

    func handle(_ urls: [URL]) {
        var pdfs: [URL] = []
        for u in urls {
            if u.scheme == "splitexercises" { handleScheme(u); continue }
            guard u.isFileURL else { continue }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir), isDir.boolValue {
                let inside = (try? FileManager.default.contentsOfDirectory(at: u, includingPropertiesForKeys: nil)) ?? []
                pdfs += inside.filter { $0.pathExtension.lowercased() == "pdf" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            } else if u.pathExtension.lowercased() == "pdf" {
                pdfs.append(u)
            }
        }
        guard !pdfs.isEmpty else { return }
        enqueue(pdfs)
    }

    func handleScheme(_ u: URL) {
        switch u.host {
        case "settings": showSettings()
        case "split":
            let items = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems ?? []
            handle(items.filter { $0.name == "path" }.compactMap { $0.value }.map { URL(fileURLWithPath: $0) })
        default: break
        }
    }

    func enqueue(_ urls: [URL]) {
        if !model.s.onboardingDone {
            pending += urls
            showOnboarding()
            return
        }
        if model.s.askBeforeEachRun || NSEvent.modifierFlags.contains(.option) {
            showRunOptions(urls)
        } else {
            run(urls, settings: model.s)
        }
    }

    // MARK: ejecución

    func run(_ urls: [URL], settings: Settings) {
        busy += 1
        toast.show(.working, title: tr("Dividiendo…", "Splitting…"),
                   detail: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) PDFs")
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [(URL, Result<SplitOutcome, Error>)] = []
            for u in urls { results.append((u, Result { try Splitter.split(u, settings: settings) })) }
            DispatchQueue.main.async { self.finish(results, settings: settings) }
        }
    }

    func finish(_ results: [(URL, Result<SplitOutcome, Error>)], settings: Settings) {
        busy -= 1
        let oks = results.compactMap { try? $0.1.get() }
        let errs: [(URL, Error)] = results.compactMap { if case .failure(let e) = $0.1 { return ($0.0, e) } else { return nil } }

        if oks.isEmpty, let first = errs.first {
            toast.show(.error, title: tr("No se pudo dividir", "Couldn't split"),
                       detail: "\(first.0.lastPathComponent): \(first.1.localizedDescription)",
                       actions: [ToastAction(title: tr("Ajustes", "Settings"), run: { [weak self] in self?.toast.hide(); self?.showSettings() })],
                       autoHide: 12)
            return
        }
        if settings.revealResult, let o = oks.first { NSWorkspace.shared.activateFileViewerSelecting([o.resultURL]) }
        if settings.openResult, let o = oks.first { NSWorkspace.shared.open(o.resultURL) }
        guard settings.notify else { maybeQuit(); return }

        let title: String, detail: String
        if oks.count == 1, errs.isEmpty {
            let r = oks[0].report
            title = tr("\(r.exerciseCount) ejercicios separados", "\(r.exerciseCount) exercises split")
            var d = "\(oks[0].resultURL.lastPathComponent) · \(r.sourcePages) → \(r.outputPages) " + tr("páginas", "pages")
            if r.flaggedCount > 0 { d += "\n" + tr("\(r.flaggedCount) para revisar (largos o reducidos)", "\(r.flaggedCount) to review (long or scaled down)") }
            if r.usedOCR { d += "\n" + tr("PDF escaneado: usé OCR", "Scanned PDF: used OCR") }
            detail = d
        } else {
            title = tr("\(oks.count) PDFs divididos", "\(oks.count) PDFs split")
            detail = errs.isEmpty ? "" : tr("\(errs.count) con error: ", "\(errs.count) failed: ") + errs[0].0.lastPathComponent + " — " + errs[0].1.localizedDescription
        }
        var actions = [ToastAction(title: tr("Mostrar", "Show"), run: { NSWorkspace.shared.activateFileViewerSelecting(oks.map { $0.resultURL }) })]
        if oks.count == 1 {
            let id = oks[0].historyID
            actions.append(ToastAction(title: tr("Deshacer", "Undo"), run: { [weak self] in
                do { try Splitter.undo(id); self?.toast.show(.success, title: tr("Deshecho", "Undone"), detail: tr("El original ha vuelto a su sitio.", "The original is back in place."), autoHide: 4) }
                catch { self?.toast.show(.error, title: tr("No se pudo deshacer", "Couldn't undo"), detail: error.localizedDescription, autoHide: 8) }
            }))
        }
        actions.append(ToastAction(title: tr("Ajustes", "Settings"), run: { [weak self] in self?.toast.hide(); self?.showSettings() }))
        toast.show(errs.isEmpty ? .success : .warning, title: title, detail: detail, actions: actions, autoHide: 9)
    }

    // MARK: barra de menús

    func settingsChanged(_ old: Settings, _ new: Settings) {
        if old.language != new.language { Lang.forced = new.language; NSApp.mainMenu = MainMenu.build(target: self) }
        if old.showMenuBarIcon != new.showMenuBarIcon { refreshStatusItem() }
        if old.launchAtLogin != new.launchAtLogin, let err = Integrations.setLaunchAtLogin(new.launchAtLogin) {
            model.s.launchAtLogin = false
            toast.show(.warning, title: tr("No se pudo cambiar el inicio de sesión", "Couldn't change login item"), detail: err, autoHide: 8)
        }
    }

    func refreshStatusItem() {
        if model.s.showMenuBarIcon {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.autosaveName = "SplitExercisesStatusItem"   // identidad estable: la barra (y gestores como Bartender) recuerdan su posición
            item.isVisible = true
            if let b = item.button {
                let img = NSImage(systemSymbolName: "rectangle.split.1x2", accessibilityDescription: "SplitExercises")
                img?.isTemplate = true
                b.image = img
                b.toolTip = "SplitExercises"
            }
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let s = model.s
        let head = NSMenuItem(title: "SplitExercises", action: nil, keyEquivalent: ""); head.isEnabled = false
        menu.addItem(head)
        menu.addItem(ActionItem(tr("Dividir PDF…", "Split PDF…"), key: "o") { [weak self] in self?.chooseFiles() })
        let hist = History.load()
        menu.addItem(ActionItem(tr("Deshacer última división", "Undo last split"), enabled: !hist.isEmpty) { [weak self] in
            do { let e = try Splitter.undo(); self?.toast.show(.success, title: tr("Deshecho", "Undone"), detail: URL(fileURLWithPath: e.originalHome).lastPathComponent, autoHide: 4) }
            catch { self?.toast.show(.error, title: tr("No se pudo deshacer", "Couldn't undo"), detail: error.localizedDescription, autoHide: 8) }
        })
        menu.addItem(.separator())

        // Ajustes rápidos
        menu.addItem(ActionItem(tr("Etiqueta «Ejercicio N»", "“Exercise N” label"), checked: s.labelEnabled) { [weak self] in self?.model.s.labelEnabled.toggle() })
        let ans = NSMenuItem(title: tr("Zona de respuesta", "Answer area"), action: nil, keyEquivalent: ""); let ansM = NSMenu()
        for (v, t) in [(AnswerSpace.blank, tr("En blanco", "Blank")), (.lines, tr("Rayas", "Lines")), (.grid, tr("Cuadrícula", "Grid")), (.dots, tr("Puntos", "Dots"))] {
            ansM.addItem(ActionItem(t, checked: s.answerSpace == v) { [weak self] in self?.model.s.answerSpace = v })
        }
        ans.submenu = ansM; menu.addItem(ans)
        let orig = NSMenuItem(title: tr("Original", "Original"), action: nil, keyEquivalent: ""); let origM = NSMenu()
        for (v, t) in [(OriginalAction.moveToDocuments, tr("Mover a Documentos/\(s.originalFolderName)", "Move to Documents/\(s.originalFolderName)")),
                       (.trash, tr("Mandar a la Papelera", "Move to Trash")), (.keep, tr("Dejarlo donde está", "Leave in place"))] {
            origM.addItem(ActionItem(t, checked: s.originalAction == v) { [weak self] in self?.model.s.originalAction = v })
        }
        orig.submenu = origM; menu.addItem(orig)
        menu.addItem(ActionItem(tr("Preguntar antes de cada división", "Ask before each split"), checked: s.askBeforeEachRun) { [weak self] in self?.model.s.askBeforeEachRun.toggle() })
        menu.addItem(.separator())
        menu.addItem(ActionItem(tr("Ajustes…", "Settings…"), key: ",") { [weak self] in self?.showSettings() })
        menu.addItem(ActionItem(tr("Abrir al iniciar sesión", "Open at login"), checked: s.launchAtLogin) { [weak self] in self?.model.s.launchAtLogin.toggle() })
        menu.addItem(ActionItem(tr("Ocultar icono de la barra de menús…", "Hide menu bar icon…")) { [weak self] in self?.confirmHideIcon() })
        menu.addItem(.separator())
        menu.addItem(ActionItem(tr("Acerca de SplitExercises", "About SplitExercises")) { [weak self] in self?.showAbout() })
        let q = NSMenuItem(title: tr("Salir de SplitExercises", "Quit SplitExercises"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(q)
    }

    func confirmHideIcon() {
        let a = NSAlert()
        a.messageText = tr("¿Ocultar el icono de la barra de menús?", "Hide the menu bar icon?")
        a.informativeText = tr("SplitExercises seguirá funcionando desde el clic derecho en un PDF. Para cambiar ajustes, abre la app desde Spotlight o Launchpad, o mantén ⌥ (Option) al lanzar la acción.",
                               "SplitExercises keeps working from the right-click menu on a PDF. To change settings, open the app from Spotlight or Launchpad, or hold ⌥ (Option) when you run the action.")
        a.addButton(withTitle: tr("Ocultar icono", "Hide icon"))
        a.addButton(withTitle: tr("Cancelar", "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn { model.s.showMenuBarIcon = false }
    }

    func chooseFiles() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.pdf]
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if p.runModal() == .OK { enqueue(p.urls) }
    }

    // MARK: ventanas

    @objc func showSettingsAction() { showSettings() }

    func showSettings() {
        if settingsWindow == nil {
            let w = makeWindow(title: tr("SplitExercises — Ajustes", "SplitExercises — Settings"), view: SettingsView(model: model, host: self))
            settingsWindow = w
        }
        present(settingsWindow!)
    }

    /// Dev: `SPLITEXERCISES_SHOT=onboarding:N|settings:N|done:/ruta.png` captura la ventana real (controles nativos) para el README.
    func captureWindow(spec: String) {
        let parts = spec.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { NSApp.terminate(nil); return }
        let out = parts[2]
        func publish(_ w: NSWindow) { // dev: el script de capturas lee el número de ventana y usa screencapture -l
            present(w)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { try? "\(w.windowNumber)".write(toFile: out, atomically: true, encoding: .utf8) }
        }
        if parts[0] == "settingswin" { publish(makeWindow(title: tr("SplitExercises — Ajustes", "SplitExercises — Settings"), view: SettingsView(model: model, host: self, startTab: Int(parts[1]) ?? 0))); return }
        if parts[0] == "runopts" {
            let v = RunOptionsView(files: [URL(fileURLWithPath: "/tmp/fx/before.pdf")], base: model.s, onRun: { _, _ in }, onCancel: {}, onSettings: {})
            publish(makeWindow(title: tr("Dividir con SplitExercises", "Split with SplitExercises"), view: v)); return
        }
        if parts[0] == "menu" { // maqueta limpia de la barra + el menú real; la captura la hace screencapture desde fuera
            guard let scr = NSScreen.main else { return }
            let bd = NSWindow(contentRect: scr.frame, styleMask: .borderless, backing: .buffered, defer: false)
            bd.level = NSWindow.Level(rawValue: 100)
            bd.contentView = NSHostingView(rootView: VStack(spacing: 0) {
                Color.clear.frame(height: 40)
                ZStack(alignment: .leading) {
                    Color(white: 0.07)
                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.22)).frame(width: 32, height: 22)
                        Image(systemName: "rectangle.split.1x2").font(.system(size: 14)).foregroundColor(.white)
                    }.padding(.leading, 200)
                }.frame(height: 24)
                Spacer()
            }.background(Color(white: 0.13)))
            NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
            bd.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            backdropWindow = bd
            bd.orderFrontRegardless()
            refreshStatusItem()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard let m = self.statusItem?.menu else { return }
                m.popUp(positioning: nil, at: NSPoint(x: 200, y: scr.frame.maxY - 64), in: nil)
            }
            return
        }
        let w: NSWindow
        switch parts[0] {
        case "onboarding":
            let v = OnboardingView(model: model, startStep: Int(parts[1]) ?? 0) {}
            w = makeWindow(title: "", view: v)
        case "done":
            w = makeWindow(title: "", view: OnboardingView(model: model, startStep: 2, startDone: true) {})
        default:
            w = makeWindow(title: "", view: SettingsView(model: model, host: self))
        }
        present(w)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if let v = w.contentView?.superview ?? w.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                v.cacheDisplay(in: v.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
            }
            NSApp.terminate(nil)
        }
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let v = OnboardingView(model: model) { [weak self] in self?.finishOnboarding() }
            onboardingWindow = makeWindow(title: tr("Bienvenido a SplitExercises", "Welcome to SplitExercises"), view: v)
        }
        present(onboardingWindow!)
    }

    func finishOnboarding() {
        model.s.onboardingDone = true
        onboardingWindow?.close()
        let urls = pending; pending = []
        if !urls.isEmpty { run(urls, settings: model.s) }
        else if !model.s.showMenuBarIcon {
            toast.show(.success, title: tr("Todo listo", "All set"),
                       detail: tr("Clic derecho en un PDF → Acciones rápidas → «SplitExercises».", "Right-click a PDF → Quick Actions → “SplitExercises”."), autoHide: 7)
        }
    }

    func showRunOptions(_ urls: [URL]) {
        runWindow?.close()
        let v = RunOptionsView(files: urls, base: model.s, onRun: { [weak self] s, saveDefault in
            guard let self else { return }
            if saveDefault { self.model.s = s }
            self.runWindow?.close()
            self.run(urls, settings: s)
        }, onCancel: { [weak self] in self?.runWindow?.close() }, onSettings: { [weak self] in self?.showSettings() })
        runWindow = makeWindow(title: tr("Dividir con SplitExercises", "Split with SplitExercises"), view: v)
        present(runWindow!)
    }

    func makeWindow<V: View>(title: String, view: V) -> NSWindow {
        let host = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: host)
        w.title = title
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        return w
    }

    func present(_ w: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        if w === settingsWindow { settingsWindow = nil }
        if w === onboardingWindow { onboardingWindow = nil }
        if w === runWindow { runWindow = nil }
        DispatchQueue.main.async { [self] in
            if ![settingsWindow, onboardingWindow, runWindow].contains(where: { $0?.isVisible ?? false }) {
                NSApp.setActivationPolicy(.accessory)
            }
            maybeQuit()
        }
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: tr("Divide PDFs de ejercicios en una hoja por ejercicio.\nSoftware libre (MIT).", "Splits exercise PDFs into one sheet per exercise.\nFree software (MIT)."))
        ])
    }

    /// Sin icono en la barra y sin nada que hacer, la app se cierra sola (no deja nada residente).
    func maybeQuit() {
        guard !model.s.showMenuBarIcon, busy == 0, pending.isEmpty, !toast.isVisible,
              ![settingsWindow, onboardingWindow, runWindow].contains(where: { $0?.isVisible ?? false }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            if !model.s.showMenuBarIcon, busy == 0, !toast.isVisible,
               ![settingsWindow, onboardingWindow, runWindow].contains(where: { $0?.isVisible ?? false }) { NSApp.terminate(nil) }
        }
    }
}
