import SwiftUI
import AppKit
import ExSplitCore

/// Primer uso: 3 pasos (cómo quieres las hojas → dónde vive la app → integración con Finder).
struct OnboardingView: View {
    @ObservedObject var model: SettingsModel
    var finish: () -> Void
    @StateObject private var stepBox = Local(0)
    @StateObject private var installQuickBox = Local(true)
    @StateObject private var enableExtBox = Local(false)
    private var step: Int { get { stepBox.v } nonmutating set { stepBox.v = newValue } }
    private var installQuick: Bool { installQuickBox.v }
    private var enableExt: Bool { enableExtBox.v }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in Capsule().fill(i <= step ? Color.accentColor : Color.gray.opacity(0.3)).frame(height: 4) }
            }.padding(.horizontal, 28).padding(.top, 20)

            Group {
                switch step {
                case 0: stepLayout
                case 1: stepMenuBar
                default: stepFinder
                }
            }
            .padding(.horizontal, 28).padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()
            HStack {
                if step > 0 { Button(tr("Atrás", "Back")) { step -= 1 } }
                Spacer()
                if step < 2 {
                    Button(tr("Siguiente", "Next")) { step += 1 }.keyboardShortcut(.defaultAction)
                } else {
                    Button(tr("Empezar", "Get started")) { apply() }.keyboardShortcut(.defaultAction)
                }
            }.padding(16)
        }
        .frame(width: 640, height: 520)
    }

    // 1
    var stepLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("¿Cómo quieres tus hojas?", "How do you want your sheets?")).font(.title2.bold())
                Spacer()
                Picker("", selection: $model.s.language) {
                    Text("Auto").tag(AppLanguage.auto)
                    Text("Español").tag(AppLanguage.es)
                    Text("English").tag(AppLanguage.en)
                }.labelsHidden().pickerStyle(.menu).frame(width: 100)
            }
            Text(tr("ExSplit convierte un PDF de ejercicios en uno con un ejercicio por hoja. Elige lo básico; todo se puede cambiar luego en Ajustes.",
                    "ExSplit turns an exercise PDF into one with one exercise per sheet. Pick the basics; you can change everything later in Settings."))
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Etiqueta «Ejercicio N»", "“Exercise N” label")).fontWeight(.medium)
                        HStack(alignment: .center, spacing: 12) {
                            PositionPicker(position: $model.s.labelPosition)
                            Toggle(tr("Mostrar", "Show"), isOn: $model.s.labelEnabled)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Debajo del enunciado", "Below the question")).fontWeight(.medium)
                        Picker("", selection: $model.s.answerSpace) { ForEach(AnswerSpace.allCases) { Text($0.title).tag($0) } }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 280)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("El PDF original…", "The original PDF…")).fontWeight(.medium)
                        Picker("", selection: $model.s.originalAction) { ForEach(OriginalAction.allCases) { Text($0.title).tag($0) } }
                            .pickerStyle(.radioGroup).labelsHidden()
                        if model.s.originalAction == .moveToFolder {
                            TextField(tr("Nombre de la subcarpeta", "Subfolder name"), text: $model.s.originalFolderName, prompt: Text("ExSplit"))
                                .frame(width: 220)
                            Text(tr("Recomendado: ExSplit. Se crea junto al PDF.", "Recommended: ExSplit. Created next to the PDF.")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                PagePreview(s: model.s).frame(width: 190, height: 270)
            }
        }
    }

    // 2
    var stepMenuBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Dónde vive ExSplit", "Where ExSplit lives")).font(.title2.bold())
            menuBarMock
            Text(tr("ExSplit puede quedarse en la barra de menús: desde ahí cambias lo más usado y deshaces la última división a un clic. No tiene icono en el Dock y casi no consume nada.",
                    "ExSplit can live in the menu bar: from there you tweak the essentials and undo the last split in one click. No Dock icon, and it uses almost nothing."))
                .fixedSize(horizontal: false, vertical: true)
            Label {
                Text(tr("Cómo se usa: clic derecho en un PDF → Acciones rápidas → «Dividir ejercicios con ExSplit» (también en Servicios y Abrir con). El resultado aparece en la misma carpeta.",
                        "How you use it: right-click a PDF → Quick Actions → “Split exercises with ExSplit” (also under Services and Open With). The result appears in the same folder."))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            } icon: { Image(systemName: "cursorarrow.click.2").foregroundStyle(Color.accentColor) }
            Picker("", selection: $model.s.showMenuBarIcon) {
                Text(tr("Sí, mostrar el icono (recomendado)", "Yes, show the icon (recommended)")).tag(true)
                Text(tr("No, prefiero que no ocupe sitio", "No, I'd rather it took no space")).tag(false)
            }.pickerStyle(.radioGroup).labelsHidden()
            if model.s.showMenuBarIcon {
                Toggle(tr("Abrir al iniciar sesión", "Open at login"), isOn: $model.s.launchAtLogin)
            } else {
                Label {
                    Text(tr("Sin icono la app solo se abre cuando la usas y se cierra sola. Para cambiar ajustes más adelante: ábrela desde Spotlight o Launchpad, o mantén ⌥ (Option) al lanzar la acción desde el clic derecho para elegir opciones solo esa vez.",
                            "Without the icon the app only opens when you use it and quits by itself. To change settings later: open it from Spotlight or Launchpad, or hold ⌥ (Option) when you run the action from the right-click menu to pick options just that once."))
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                } icon: { Image(systemName: "lightbulb").foregroundStyle(.yellow) }
                .padding(10).background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.12)))
            }
        }
    }

    var menuBarMock: some View {
        HStack(spacing: 14) {
            Spacer()
            Image(systemName: "wifi"); Image(systemName: "battery.75")
            Image(systemName: "rectangle.split.1x2")
                .padding(4).background(RoundedRectangle(cornerRadius: 5).fill(model.s.showMenuBarIcon ? Color.accentColor.opacity(0.35) : Color.clear))
                .opacity(model.s.showMenuBarIcon ? 1 : 0.15)
            Text("Mon 9:41").font(.system(size: 12))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12).frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.18)))
    }

    // 3
    var stepFinder: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Úsalo con clic derecho", "Use it with a right-click")).font(.title2.bold())
            Text(tr("Haz clic derecho sobre cualquier PDF. Elige dónde quieres encontrar ExSplit:", "Right-click any PDF. Choose where you want to find ExSplit:"))
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $installQuickBox.v) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Acciones rápidas (y Servicios)", "Quick Actions (and Services)")).fontWeight(.medium)
                        Text(tr("Clic derecho → Acciones rápidas → «Dividir ejercicios con ExSplit».", "Right-click → Quick Actions → “Split exercises with ExSplit”.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.square.fill").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Abrir con", "Open With")).fontWeight(.medium)
                        Text(tr("Clic derecho → Abrir con → ExSplit. Siempre disponible, no cambia tu lector de PDF por defecto.", "Right-click → Open With → ExSplit. Always available; doesn't change your default PDF viewer.")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $enableExtBox.v) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Opción directa en el menú (experimental)", "Direct menu item (experimental)")).fontWeight(.medium)
                        Text(tr("Una entrada «Dividir ejercicios» en el propio menú, sin submenús. Usa una extensión de Finder: puede que macOS te pida activarla en Ajustes del Sistema.", "A “Split exercises” item right in the menu, no submenus. Uses a Finder extension: macOS may ask you to enable it in System Settings.")).font(.caption).foregroundStyle(.secondary)
                    }
                }.disabled(!Integrations.finderExtensionBundled)
            }
            Spacer(minLength: 0)
            Text(tr("La primera vez, macOS puede pedir permiso para acceder a tus carpetas (Documentos, Escritorio…): es normal, los PDFs solo se procesan en tu Mac.", "The first time, macOS may ask permission to access your folders (Documents, Desktop…): that's normal; PDFs are only processed on your Mac."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    func apply() {
        if installQuick { try? Integrations.installQuickAction() }
        if enableExt { Integrations.enableFinderExtension { _ in } }
        finish()
    }
}

/// Opciones solo para esta ejecución (⌥ al lanzar, o «preguntar cada vez»).
struct RunOptionsView: View {
    let files: [URL]
    @StateObject var st: Local<Settings>
    var onRun: (Settings, Bool) -> Void
    var onCancel: () -> Void
    var onSettings: () -> Void
    @StateObject private var saveBox = Local(false)
    @StateObject private var detectedBox = Local(tr("Analizando…", "Analysing…"))

    init(files: [URL], base: Settings, onRun: @escaping (Settings, Bool) -> Void, onCancel: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.files = files; self._st = StateObject(wrappedValue: Local(base)); self.onRun = onRun; self.onCancel = onCancel; self.onSettings = onSettings
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(files.count == 1 ? files[0].lastPathComponent : tr("\(files.count) PDFs", "\(files.count) PDFs")).font(.headline).lineLimit(1)
                Text(detectedBox.v).font(.caption).foregroundStyle(.secondary)
                Form {
                    Picker(tr("Papel", "Paper"), selection: $st.v.paper) { ForEach(PaperSize.allCases) { Text($0.title).tag($0) } }
                    Picker(tr("Debajo", "Below"), selection: $st.v.answerSpace) { ForEach(AnswerSpace.allCases) { Text($0.title).tag($0) } }
                    Toggle(tr("Etiqueta", "Label"), isOn: $st.v.labelEnabled)
                    if st.v.labelEnabled {
                        Picker(tr("Posición", "Position"), selection: $st.v.labelPosition) { ForEach(LabelPosition.allCases) { Text($0.title).tag($0) } }
                    }
                    Picker(tr("Original", "Original"), selection: $st.v.originalAction) { ForEach(OriginalAction.allCases) { Text($0.title).tag($0) } }
                }.formStyle(.columns)
                Toggle(tr("Guardar como mis ajustes predeterminados", "Save as my default settings"), isOn: $saveBox.v).font(.caption)
                Spacer(minLength: 0)
                HStack {
                    Button(tr("Ajustes…", "Settings…"), action: onSettings).buttonStyle(.link)
                    Spacer()
                    Button(tr("Cancelar", "Cancel"), action: onCancel).keyboardShortcut(.cancelAction)
                    Button(tr("Dividir", "Split")) { onRun(st.v, saveBox.v) }.keyboardShortcut(.defaultAction)
                }
            }.padding(18).frame(width: 360)
            Divider()
            PagePreview(s: st.v).padding(14).frame(width: 190)
        }
        .frame(width: 550, height: 380)
        .task {
            let url = files[0], cfg = st.v
            let r = await Task.detached { try? Splitter.analyze(url, settings: cfg) }.value
            if let r { detectedBox.v = tr("Detecto \(r.exercises) ejercicios", "Found \(r.exercises) exercises") + (r.usedOCR ? " (OCR)" : "") }
            else { detectedBox.v = tr("No reconozco ejercicios numerados (revisa Ajustes → Detección)", "No numbered exercises recognised (check Settings → Detection)") }
        }
    }
}
