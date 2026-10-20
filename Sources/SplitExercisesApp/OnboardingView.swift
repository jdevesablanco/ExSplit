import SwiftUI
import AppKit
import SplitExercisesCore

/// Primer uso: 3 pasos (cómo quieres las hojas → dónde vive la app → integración con Finder).
struct OnboardingView: View {
    @ObservedObject var model: SettingsModel
    var finish: () -> Void
    let startDone: Bool
    @StateObject private var stepBox: Local<Int>
    @StateObject private var installQuickBox = Local(true)
    @StateObject private var doneBox: Local<Bool>   // pantalla final
    @StateObject private var dirBox = Local(1)   // 1 = avanzando, -1 = retrocediendo (dirección de la transición)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(model: SettingsModel, startStep: Int = 0, startDone: Bool = false, finish: @escaping () -> Void) {
        _model = ObservedObject(wrappedValue: model)
        self.finish = finish
        self.startDone = startDone
        _stepBox = StateObject(wrappedValue: Local(startStep))
        _doneBox = StateObject(wrappedValue: Local(startDone))
    }

    private var step: Int { get { stepBox.v } nonmutating set { stepBox.v = newValue } }
    private var installQuick: Bool { installQuickBox.v }

    private func go(_ delta: Int) {
        dirBox.v = delta
        let anim: Animation? = reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86)
        withAnimation(anim) { step += delta }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(tr("Paso \(step + 1) de 3", "Step \(step + 1) of 3")).font(.caption).foregroundStyle(.secondary)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)))
                    .clipped()
                Spacer()
                LanguageSwitch(model: model)
            }.padding(.horizontal, 28).padding(.top, 16)
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.3))
                        // El relleno crece de izquierda a derecha al avanzar y se recoge al retroceder; el escalonado hace que "corra" por la barra.
                        Capsule().fill(Color.accentColor)
                            .scaleEffect(x: i <= step ? 1 : 0.0001, y: 1, anchor: .leading)
                            .opacity(i <= step ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45).delay(dirBox.v > 0 ? 0 : 0.08 * Double(2 - i)), value: step)
                    }
                    .frame(height: i == step ? 6 : 4)
                    .shadow(color: Color.accentColor.opacity(i == step ? 0.55 : 0), radius: 4)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: step)
                }
            }.padding(.horizontal, 28).padding(.top, 8)

            ZStack(alignment: .topLeading) {
                Group {
                    switch step {
                    case 0: stepLayout
                    case 1: stepMenuBar
                    default: stepFinder
                    }
                }
                .id(step)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: dirBox.v > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: dirBox.v > 0 ? .leading : .trailing).combined(with: .opacity)))
            }
            .padding(.horizontal, 28).padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()

            Divider()
            HStack {
                if step > 0 { Button(tr("Atrás", "Back")) { go(-1) } }
                Spacer()
                if step < 2 {
                    Button(tr("Siguiente", "Next")) { go(1) }.keyboardShortcut(.defaultAction)
                } else {
                    Button(tr("Empezar", "Get started")) { apply() }.keyboardShortcut(.defaultAction)
                }
            }.padding(16)
        }
        .frame(width: 700, height: 600)
        .overlay {
            if doneBox.v { OnboardingDoneView(finish: finish, startPhase: startDone ? 3 : 0).transition(.opacity) }
        }
    }

    // 1
    var stepLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("¿Cómo quieres tus hojas?", "How do you want your sheets?")).font(.title2.bold())
            Text(tr("SplitExercises convierte un PDF de ejercicios en uno con un ejercicio por hoja. Elige lo básico; todo se puede cambiar luego en Ajustes.",
                    "SplitExercises turns an exercise PDF into one with one exercise per sheet. Pick the basics; you can change everything later in Settings."))
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(tr("Etiqueta «Ejercicio N»", "“Exercise N” label")).fontWeight(.medium)
                            Spacer()
                            Toggle(tr("Mostrar", "Show"), isOn: $model.s.labelEnabled).toggleStyle(.checkbox)
                        }.frame(width: 280)
                        PositionPicker(position: $model.s.labelPosition, width: 280, enabled: model.s.labelEnabled)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Debajo del enunciado", "Below the question")).fontWeight(.medium)
                        Picker("", selection: $model.s.answerSpace) { ForEach(AnswerSpace.allCases) { Text($0.title).tag($0) } }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 280)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("El PDF original…", "The original PDF…")).fontWeight(.medium)
                        Picker("", selection: $model.s.originalAction) { ForEach(OriginalAction.visibleCases) { Text($0.title).tag($0) } }
                            .pickerStyle(.radioGroup).labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Nombre del resultado", "Result name")).fontWeight(.medium)
                        TextField(tr("Añadir al nombre (opcional)", "Add to the name (optional)"), text: suffixBinding, prompt: Text(Settings().effectiveSuffix))
                            .frame(width: 220)
                        nameExample
                    }
                }
                Spacer(minLength: 0)
                PagePreview(s: model.s).frame(width: 258, height: 365)
            }
        }
    }

    private var nameExample: some View {
        let extra = (model.s.originalAction == .keep || model.s.outputNaming == .suffix) ? model.s.effectiveSuffix : ""
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(tr("Original", "Original")).foregroundStyle(.secondary).frame(width: 66, alignment: .leading)
                Text("tema1.pdf")
            }
            HStack(spacing: 8) {
                Text(tr("Resultado", "Result")).foregroundStyle(.secondary).frame(width: 66, alignment: .leading)
                HStack(spacing: 0) {
                    Text("tema1")
                    if !extra.isEmpty {
                        Text(extra).padding(.horizontal, 2)
                            .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.accentColor.opacity(0.4)))
                    }
                    Text(".pdf")
                }
            }
        }
        .font(.system(.caption, design: .monospaced))
        .animation(.easeInOut(duration: 0.2), value: extra)
    }

    private var suffixBinding: Binding<String> {
        Binding(get: { model.s.outputNaming == .suffix ? model.s.outputSuffix : "" },
                set: { model.s.outputSuffix = $0; model.s.outputNaming = $0.isEmpty ? .sameAsOriginal : .suffix })
    }

    // 2
    var stepMenuBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Dónde vive SplitExercises", "Where SplitExercises lives")).font(.title2.bold())
            menuBarMock
            Text(tr("SplitExercises puede quedarse en la barra de menús: desde ahí cambias lo más usado y deshaces la última división a un clic. No tiene icono en el Dock y casi no consume nada.",
                    "SplitExercises can live in the menu bar: from there you tweak the essentials and undo the last split in one click. No Dock icon, and it uses almost nothing."))
                .fixedSize(horizontal: false, vertical: true)
            Label {
                Text(tr("Cómo se usa: clic derecho en un PDF → Acciones rápidas → «SplitExercises» (también en Servicios y Abrir con). El resultado aparece en la misma carpeta.",
                        "How you use it: right-click a PDF → Quick Actions → “SplitExercises” (also under Services and Open With). The result appears in the same folder."))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            } icon: { Image(systemName: "cursorarrow.click.2").foregroundStyle(Color.accentColor) }
            Toggle(tr("Abrir al iniciar sesión", "Open at login"), isOn: $model.s.launchAtLogin)
        }
        .onAppear { model.s.showMenuBarIcon = true }
    }

    var menuBarMock: some View {
        HStack(spacing: 14) {
            Spacer()
            Image(systemName: "rectangle.split.1x2")
                .padding(4).background(RoundedRectangle(cornerRadius: 5).fill(model.s.showMenuBarIcon ? Color.accentColor.opacity(0.35) : Color.clear))
                .opacity(model.s.showMenuBarIcon ? 1 : 0.15)
            Image(systemName: "wifi"); Image(systemName: "battery.75")
            Text("Mon 9:41").font(.system(size: 12))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12).frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.18)))
    }

    // 3
    var stepFinder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Úsalo con clic derecho", "Use it with a right-click")).font(.title2.bold())
            Text(tr("Haz clic derecho sobre cualquier PDF. Elige dónde quieres encontrar SplitExercises:", "Right-click any PDF. Choose where you want to find SplitExercises:"))
            HStack(alignment: .top, spacing: 10) {
                FinderChoiceCard(kind: .quickActions,
                                 title: tr("Acciones rápidas (y Servicios)", "Quick Actions (and Services)"),
                                 badge: tr("Recomendado", "Recommended"),
                                 detail: tr("Clic derecho → Acciones rápidas → «SplitExercises».", "Right-click → Quick Actions → “SplitExercises”."),
                                 isOn: $installQuickBox.v)
                FinderChoiceCard(kind: .openWith,
                                 title: tr("Abrir con", "Open With"),
                                 badge: tr("Siempre disponible", "Always available"),
                                 detail: tr("Clic derecho → Abrir con → SplitExercises. No cambia tu lector de PDF por defecto.", "Right-click → Open With → SplitExercises. Doesn't change your default PDF viewer."),
                                 isOn: .constant(true), locked: true)
            }
            .frame(maxHeight: .infinity)
            Text(tr("La primera vez, macOS puede pedir permiso para acceder a tus carpetas (Documentos, Escritorio…): es normal, los PDFs solo se procesan en tu Mac.", "The first time, macOS may ask permission to access your folders (Documents, Desktop…): that's normal; PDFs are only processed on your Mac."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)
        }
    }

    func apply() {
        if installQuick { try? Integrations.installQuickAction() }
        withAnimation(.easeInOut(duration: 0.35)) { doneBox.v = true }
    }
}

struct LanguageSwitch: View {
    @ObservedObject var model: SettingsModel
    @Namespace private var ns
    private var isES: Bool { model.s.language == .es || (model.s.language == .auto && (Locale.preferredLanguages.first ?? "en").hasPrefix("es")) }

    private func seg(_ title: String, es: Bool) -> some View {
        let selected = isES == es
        return Button { withAnimation(.easeInOut(duration: 0.18)) { model.s.language = es ? .es : .en } } label: {
            Text(title).font(.system(size: 11, weight: .semibold))
                .frame(width: 32, height: 22)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(nsColor: .controlColor))
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                            .matchedGeometryEffect(id: "sel", in: ns)
                    }
                }
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 0) { seg("ES", es: true); seg("EN", es: false) }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.gray.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
            .help(tr("Idioma: español / inglés", "Language: Spanish / English"))
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
                    Picker(tr("Original", "Original"), selection: $st.v.originalAction) { ForEach(OriginalAction.visibleCases) { Text($0.title).tag($0) } }
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


/// Tarjeta vertical seleccionable: marca, título, maqueta del menú de Finder con la entrada resaltada y explicación.
struct FinderChoiceCard: View {
    let kind: FinderMenuMock.Kind
    let title: String
    var badge: String? = nil
    let detail: String
    @Binding var isOn: Bool
    var locked = false          // siempre activa (Abrir con): no se puede desmarcar
    var disabled = false

    var body: some View {
        Button {
            guard !locked && !disabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .font(.system(size: 17))
                        .foregroundStyle(locked ? Color.secondary : (isOn ? Color.accentColor : Color.secondary))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 13, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        if let badge {
                            Text(badge).font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(locked ? Color.gray.opacity(0.25) : Color.accentColor.opacity(0.85)))
                                .foregroundStyle(locked ? Color.secondary : Color.white)
                        }
                    }
                    Spacer(minLength: 0)
                }
                FinderMenuMock(kind: kind)
                    .frame(maxWidth: .infinity, minHeight: 190, maxHeight: 190, alignment: .top)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(locked ? Color.gray.opacity(0.28) : (isOn ? Color.accentColor.opacity(0.10) : Color.gray.opacity(0.08))))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(locked ? Color.gray.opacity(0.7) : (isOn ? Color.accentColor : Color.gray.opacity(0.3)), lineWidth: isOn ? 2 : 1))
            .opacity(disabled ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Maqueta del menú contextual de Finder sobre un PDF, como se ve en macOS, con la entrada de SplitExercises resaltada.
struct FinderMenuMock: View {
    enum Kind { case quickActions, openWith }
    let kind: Kind

    private struct Row: Identifiable {
        let id = UUID()
        var title: String
        var sub = false
        var sep = false
        var hl = false
    }
    private let rowH: CGFloat = 17, sepH: CGFloat = 9, pad: CGFloat = 4
    private var menuW: CGFloat { 156 }
    private var subW: CGFloat { 178 }
    private var overlap: CGFloat { 52 }

    private var mainRows: [Row] {
        var r: [Row] = [
            Row(title: tr("Abrir", "Open")),
            Row(title: tr("Abrir con", "Open With"), sub: true, hl: kind == .openWith),
            Row(title: "", sep: true),
            Row(title: tr("Mover a la papelera", "Move to Trash")),
            Row(title: tr("Obtener información", "Get Info")),
            Row(title: tr("Renombrar", "Rename")),
            Row(title: "", sep: true),
        ]
        r.append(Row(title: tr("Acciones rápidas", "Quick Actions"), sub: true, hl: kind == .quickActions))
        r.append(Row(title: tr("Servicios", "Services"), sub: true))
        return r
    }
    private var subRows: [Row]? {
        switch kind {
        case .quickActions:
            return [Row(title: tr("Marcar", "Markup")),
                    Row(title: tr("Girar a la izquierda", "Rotate Left")),
                    Row(title: tr("SplitExercises", "SplitExercises"), hl: true),
                    Row(title: tr("Personalizar…", "Customize…"))]
        case .openWith:
            return [Row(title: tr("Vista Previa (predeterminada)", "Preview (default)")),
                    Row(title: "", sep: true),
                    Row(title: "SplitExercises", hl: true),
                    Row(title: "Safari"),
                    Row(title: tr("Otra…", "Other…"))]
        }
    }
    private func height(_ rows: [Row]) -> CGFloat { rows.reduce(pad * 2) { $0 + ($1.sep ? sepH : rowH) } }
    private func yOf(_ rows: [Row], where hit: (Row) -> Bool) -> CGFloat {
        var y = pad
        for r in rows { if hit(r) { return y }; y += r.sep ? sepH : rowH }
        return pad
    }

    private var designW: CGFloat { subRows == nil ? menuW : menuW - overlap + subW }
    private var designH: CGFloat { height(mainRows) }

    var body: some View {
        let main = mainRows
        GeometryReader { g in
            let sc = min(1.15, g.size.width / designW)
            ZStack(alignment: .topLeading) {
                panel(main, width: menuW)
                if let sub = subRows {
                    let parentY = yOf(main) { $0.hl && $0.sub }
                    let y = max(0, min(parentY - pad, designH - height(sub)))
                    panel(sub, width: subW).offset(x: menuW - overlap, y: y)
                }
            }
            .frame(width: designW, height: max(designH, subRows.map { height($0) } ?? 0), alignment: .topLeading)
            .scaleEffect(sc, anchor: .topLeading)
            .frame(width: designW * sc, height: designH * sc, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func panel(_ rows: [Row], width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { r in
                if r.sep {
                    Divider().padding(.horizontal, 6).frame(height: sepH)
                } else {
                    HStack(spacing: 0) {
                        Text(r.title).font(.system(size: 9.5)).lineLimit(1)
                        Spacer(minLength: 4)
                        if r.sub { Image(systemName: "chevron.right").font(.system(size: 7, weight: .semibold)) }
                    }
                    .padding(.horizontal, 7).frame(height: rowH)
                    .foregroundStyle(r.hl ? Color.white : Color.primary)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(r.hl ? Color.accentColor : Color.clear))
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.vertical, pad)
        .frame(width: width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
    }
}
