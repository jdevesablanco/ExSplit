import SwiftUI
import AppKit
import SplitExercisesCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    weak var host: AppDelegate?

    var body: some View {
        HStack(spacing: 0) {
            TabView {
                GeneralTab(model: model).tabItem { Label(tr("General", "General"), systemImage: "gearshape") }
                FormatTab(model: model).tabItem { Label(tr("Formato", "Layout"), systemImage: "doc.richtext") }
                LabelTab(model: model).tabItem { Label(tr("Etiqueta", "Label"), systemImage: "tag") }
                FilesTab(model: model).tabItem { Label(tr("Archivos", "Files"), systemImage: "folder") }
                DetectionTab(model: model).tabItem { Label(tr("Detección", "Detection"), systemImage: "text.magnifyingglass") }
                IntegrationTab(model: model).tabItem { Label(tr("Finder", "Finder"), systemImage: "cursorarrow.click.2") }
                PackTab().tabItem { Label(tr("Combina bien con", "Pairs well with"), systemImage: "square.grid.2x2") }
                AboutTab(model: model).tabItem { Label(tr("Acerca de", "About"), systemImage: "info.circle") }
            }
            .frame(minWidth: 500)
            Divider()
            VStack(spacing: 8) {
                Text(tr("Así quedará cada hoja", "How each sheet will look")).font(.caption).foregroundStyle(.secondary)
                PagePreview(s: model.s)
                Text(summary).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(14)
            .frame(width: 250)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 800, height: 560)
    }

    var summary: String {
        let s = model.s
        return "\(s.paper.title) · " + tr("margen", "margin") + " \(Int(s.margin)) pt" + (s.labelEnabled ? " · " + s.labelPosition.title.lowercased() : "")
    }
}

// MARK: General

struct GeneralTab: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        Form {
            Section(tr("Idioma", "Language")) {
                Picker(tr("Idioma de la app", "App language"), selection: $model.s.language) {
                    Text(tr("Automático (el del sistema)", "Automatic (system language)")).tag(AppLanguage.auto)
                    Text("Español").tag(AppLanguage.es)
                    Text("English").tag(AppLanguage.en)
                }
            }
            Section(tr("Barra de menús", "Menu bar")) {
                Toggle(tr("Mostrar el icono en la barra de menús", "Show the menu bar icon"), isOn: $model.s.showMenuBarIcon)
                Text(model.s.showMenuBarIcon
                     ? tr("Desde el icono cambias lo más usado y deshaces la última división a un clic.", "From the icon you can tweak the essentials and undo the last split in one click.")
                     : tr("Sin icono, la app no se queda abierta. Para volver aquí: ábrela desde Spotlight/Launchpad, o mantén ⌥ al lanzar la acción.", "Without the icon the app doesn't stay open. To come back here: open it from Spotlight/Launchpad, or hold ⌥ when you run the action."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(tr("Abrir al iniciar sesión", "Open at login"), isOn: $model.s.launchAtLogin).disabled(!model.s.showMenuBarIcon)
            }
            Section(tr("Al dividir", "When splitting")) {
                Toggle(tr("Preguntarme las opciones cada vez", "Ask me for options every time"), isOn: $model.s.askBeforeEachRun)
                Text(tr("Si lo dejas apagado, mantén ⌥ (Option) al lanzar la acción para elegir opciones solo esa vez.", "If off, hold ⌥ (Option) when you run the action to pick options just that once."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(tr("Mostrar un aviso al terminar", "Show a notice when done"), isOn: $model.s.notify)
                Toggle(tr("Mostrar el resultado en Finder", "Reveal the result in Finder"), isOn: $model.s.revealResult)
                Toggle(tr("Abrir el resultado", "Open the result"), isOn: $model.s.openResult)
            }
        }.formStyle(.grouped)
    }
}

// MARK: Formato

struct FormatTab: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        Form {
            Section(tr("Hoja", "Sheet")) {
                Picker(tr("Papel", "Paper"), selection: $model.s.paper) { ForEach(PaperSize.allCases) { Text($0.title).tag($0) } }
                HStack {
                    Text(tr("Margen", "Margin"))
                    Slider(value: $model.s.margin, in: 10...72, step: 2)
                    Text("\(Int(model.s.margin)) pt").monospacedDigit().frame(width: 52, alignment: .trailing)
                }
                HStack {
                    Text(tr("Reducir hasta", "Shrink down to"))
                    Slider(value: $model.s.minScale, in: 0.6...1.0, step: 0.05)
                    Text("\(Int(model.s.minScale * 100)) %").monospacedDigit().frame(width: 52, alignment: .trailing)
                }
                Text(tr("Un ejercicio largo se reduce hasta este tamaño para caber en una hoja; si aun así no cabe, pasa a una segunda hoja a tamaño real.",
                        "A long exercise is shrunk down to this size to fit one sheet; if it still doesn't fit, it continues on a second sheet at full size."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(tr("Espacio para resolver", "Space to work")) {
                Picker(tr("Debajo del enunciado", "Below the question"), selection: $model.s.answerSpace) {
                    ForEach(AnswerSpace.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }
        }.formStyle(.grouped)
    }
}

// MARK: Etiqueta

struct LabelTab: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        Form {
            Section {
                Toggle(tr("Poner una etiqueta en cada hoja", "Put a label on every sheet"), isOn: $model.s.labelEnabled)
            }
            if model.s.labelEnabled {
                Section(tr("Texto", "Text")) {
                    TextField(tr("Plantilla", "Template"), text: $model.s.labelTemplate, prompt: Text(Settings().effectiveLabelTemplate))
                    Text(tr("Puedes usar {n} (número de ejercicio), {total} y {file} (nombre del PDF).", "You can use {n} (exercise number), {total} and {file} (PDF name)."))
                        .font(.caption).foregroundStyle(.secondary)
                    TextField(tr("Si sigue en otra hoja", "If it continues on another sheet"), text: $model.s.labelContinuation)
                }
                Section(tr("Posición y estilo", "Position and style")) {
                    HStack(alignment: .center, spacing: 18) {
                        PositionPicker(position: $model.s.labelPosition)
                        VStack(alignment: .leading) {
                            Text(model.s.labelPosition.title).font(.callout)
                            Stepper(value: $model.s.labelFontSize, in: 5...16, step: 1) { Text(tr("Tamaño", "Size") + " \(Int(model.s.labelFontSize)) pt") }
                            HStack { Text(tr("Color", "Color")); Slider(value: $model.s.labelGray, in: 0.2...0.9) }
                        }
                    }
                }
            }
        }.formStyle(.grouped)
    }
}

// MARK: Archivos

struct FilesTab: View {
    @ObservedObject var model: SettingsModel
    var effectiveNaming: OutputNaming { model.s.originalAction == .keep ? .suffix : model.s.outputNaming }
    private var suffixBinding: Binding<String> {
        Binding(get: { model.s.outputNaming == .suffix ? model.s.outputSuffix : "" },
                set: { model.s.outputSuffix = $0; model.s.outputNaming = $0.isEmpty ? .sameAsOriginal : .suffix })
    }

    var body: some View {
        Form {
            Section(tr("¿Qué hago con el PDF original?", "What happens to the original PDF?")) {
                Picker("", selection: $model.s.originalAction) { ForEach(OriginalAction.visibleCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.radioGroup).labelsHidden()
            }
            Section(tr("Nombre del resultado", "Result name")) {
                TextField(tr("Añadir al nombre (opcional)", "Add to the name (optional)"), text: suffixBinding, prompt: Text(Settings().effectiveSuffix))
                if model.s.originalAction == .keep {
                    Text(tr("Como el original se queda, el resultado necesita un sufijo para no pisarlo.", "Since the original stays, the result needs a suffix so it doesn't overwrite it."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(example).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    var example: String {
        let s = model.s
        let name = "ejercicios_tema1"
        let res = effectiveNaming == .suffix ? name + s.effectiveSuffix : name
        var orig = ""
        switch s.originalAction {
        case .moveToFolder: orig = "\(s.originalFolderName)/\(name).pdf"
        case .moveToDocuments: orig = "~/Documents/\(s.originalFolderName)/\(name).pdf"
        case .trash: orig = tr("Papelera", "Trash")
        case .keep: orig = "\(name).pdf"
        }
        return "→ \(res).pdf   |   " + tr("original", "original") + ": \(orig)"
    }
}

// MARK: Detección

struct DetectionTab: View {
    @ObservedObject var model: SettingsModel
    var languages: Binding<String> {
        Binding(get: { model.s.ocrLanguages.joined(separator: ", ") },
                set: { model.s.ocrLanguages = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } })
    }
    var body: some View {
        Form {
            Section(tr("Cómo reconozco el inicio de cada ejercicio", "How I recognise the start of each exercise")) {
                TextField(tr("Patrón propio (opcional)", "Custom pattern (optional)"), text: $model.s.customPattern, prompt: Text(tr("Automático", "Automatic")))
                Text(tr("Automático entiende «1.», «1)», «Ejercicio 1», «Problema 1», «Exercise 1»… Si tu PDF usa otra cosa, escribe una expresión regular con el número en el primer grupo, por ejemplo: ^\\s*Q(\\d+)\\b",
                        "Automatic understands “1.”, “1)”, “Exercise 1”, “Problem 1”… If your PDF uses something else, write a regular expression with the number in the first group, e.g. ^\\s*Q(\\d+)\\b"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(tr("PDFs escaneados (OCR)", "Scanned PDFs (OCR)")) {
                Picker("OCR", selection: $model.s.ocr) { ForEach(OCRMode.allCases) { Text($0.title).tag($0) } }
                TextField(tr("Idiomas", "Languages"), text: languages)
                Text(tr("Usa el reconocimiento de texto de macOS (Vision), sin enviar nada fuera de tu Mac. En escaneados tarda unos segundos por página.",
                        "Uses macOS text recognition (Vision); nothing leaves your Mac. On scans it takes a few seconds per page."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}

// MARK: Finder

struct IntegrationTab: View {
    @ObservedObject var model: SettingsModel
    @StateObject private var quickBox = Local(Integrations.quickActionInstalled)
    @StateObject private var errBox = Local<String?>(nil)
    @StateObject private var claudeBox = Local(ClaudeSetup.status())
    private var claude: ClaudeStatus { get { claudeBox.v } nonmutating set { claudeBox.v = newValue } }
    private var claudeStatusText: String {
        var parts: [String] = []
        if claude.claudeCode { parts.append("Claude Code") }
        if claude.desktop { parts.append(tr("app de Claude", "Claude app")) }
        return parts.isEmpty ? tr("No conectado", "Not connected") : tr("Conectado: ", "Connected: ") + parts.joined(separator: ", ")
    }
    private var quick: Bool { get { quickBox.v } nonmutating set { quickBox.v = newValue } }
    private var err: String? { get { errBox.v } nonmutating set { errBox.v = newValue } }

    var body: some View {
        Form {
            Section(tr("Clic derecho en un PDF", "Right-click on a PDF")) {
                row(icon: "bolt.fill", title: tr("Acción rápida", "Quick Action"),
                    text: tr("Clic derecho → Acciones rápidas (y también en Servicios).", "Right-click → Quick Actions (also under Services)."),
                    status: quick ? tr("Instalada", "Installed") : tr("No instalada", "Not installed")) {
                    Button(quick ? tr("Quitar", "Remove") : tr("Instalar", "Install")) {
                        do { if quick { Integrations.removeQuickAction() } else { try Integrations.installQuickAction() } } catch { err = error.localizedDescription }
                        quick = Integrations.quickActionInstalled
                    }
                }
                row(icon: "arrow.up.forward.app", title: tr("Abrir con", "Open With"),
                    text: tr("Clic derecho → Abrir con → SplitExercises.", "Right-click → Open With → SplitExercises."), status: tr("Siempre disponible", "Always available")) { EmptyView() }
            }
            if let err { Text(err).foregroundStyle(.red).font(.caption) }
            Section(tr("Con Claude", "With Claude")) {
                row(icon: "sparkles", title: tr("Claude (chat, Cowork y Claude Code)", "Claude (chat, Cowork and Claude Code)"),
                    text: tr("Pídele «divide los ejercicios de esta carpeta». Claude Code usa un skill; la app de Claude, una herramienta (se reinicia sola al instalar).",
                             "Ask “split the exercises in this folder”. Claude Code uses a skill; the Claude app uses a tool (it restarts itself on install)."),
                    status: claudeStatusText) {
                    HStack {
                        Button(claude.anyConnected ? tr("Quitar", "Remove") : tr("Instalar", "Install")) {
                            if claude.anyConnected { ClaudeSetup.disconnect(); claude = ClaudeSetup.status() }
                            else { do { claude = try Integrations.installClaude().status; err = claude.desktopError } catch { err = error.localizedDescription } }
                        }
                    }
                }
            }
            Section {
                Text(tr("Truco: mantén ⌥ (Option) al elegir cualquiera de estas opciones para decidir los ajustes solo esa vez.", "Tip: hold ⌥ (Option) when you pick any of these to choose settings just that once."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
        .onAppear { quick = Integrations.quickActionInstalled }
    }

    func row<A: View>(icon: String, title: String, text: String, status: String, @ViewBuilder action: () -> A) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(status).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            action()
        }.padding(.vertical, 2)
    }
}

// MARK: Combina bien con

struct PackTab: View {
    @StateObject private var packs = PackStore()
    var body: some View {
        ScrollView { PackAppsSection(store: packs).padding(16) }
    }
}

// MARK: Acerca de

struct AboutTab: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading) {
                        Text("SplitExercises").font(.title3.bold())
                        Text(tr("Versión", "Version") + " \(AppInfo.version) · " + tr("Software libre, licencia MIT", "Free software, MIT licence")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(tr("Convierte un PDF de ejercicios en uno con un ejercicio por hoja y espacio para resolverlo. Todo ocurre en tu Mac: no hay red ni cuentas.",
                        "Turns an exercise PDF into one with a single exercise per sheet and room to solve it. Everything happens on your Mac: no network, no accounts."))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                if let u = URL(string: AppInfo.repoURL) { Link(tr("Código fuente en GitHub", "Source code on GitHub"), destination: u) }
            }
            Section {
                Button(tr("Mostrar archivo de ajustes en Finder", "Reveal settings file in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([SettingsStore.fileURL])
                }
                Button(tr("Restablecer todos los ajustes…", "Reset all settings…"), role: .destructive) {
                    let a = NSAlert()
                    a.messageText = tr("¿Restablecer los ajustes?", "Reset settings?")
                    a.informativeText = tr("Vuelven los valores por defecto. Tus PDFs no se tocan.", "Defaults come back. Your PDFs are not touched.")
                    a.addButton(withTitle: tr("Restablecer", "Reset")); a.addButton(withTitle: tr("Cancelar", "Cancel"))
                    if a.runModal() == .alertFirstButtonReturn { var s = Settings(); s.onboardingDone = true; model.s = s }
                }
            }
        }.formStyle(.grouped)
    }
}
