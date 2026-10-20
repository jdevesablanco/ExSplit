import Foundation
import SplitExercisesCore

let usage = """
splitexercises — divide un PDF de ejercicios en una hoja por ejercicio.

USO
  splitexercises split <archivo.pdf>... [opciones]     divide aplicando tus ajustes (original → Documentos/SplitExercises, etc.)
  splitexercises generate <entrada.pdf> <salida.pdf>   solo genera, sin tocar nada más
  splitexercises analyze <archivo.pdf>                 cuenta ejercicios sin escribir
  splitexercises undo                                  deshace la última división
  splitexercises settings [--reset]                    muestra (o restablece) los ajustes
  splitexercises selftest                              prueba de humo (genera un PDF sintético y lo divide)
  splitexercises install                               copia SplitExercises.app a /Applications y la abre
  splitexercises --version

OPCIONES (sobrescriben los ajustes solo en esta ejecución)
  --paper a4|letter|a5|same     --margin PT          --min-scale 0.85
  --answer blank|lines|grid|dots
  --label "Ejercicio {n}"       --no-label           --label-pos topLeft|topCenter|topRight|bottomLeft|bottomCenter|bottomRight
  --pattern REGEX               --ocr auto|always|never
  --original move|trash|keep    --suffix " (ejercicios)"   (con --suffix el resultado no machaca el nombre original)
"""

func fail(_ m: String) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(1) }

var args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { print(usage); exit(0) }
args.removeFirst()

var s = SettingsStore.load()
Lang.forced = s.language
var files: [String] = []
var i = 0
func next(_ flag: String) -> String { i += 1; guard i < args.count else { fail("Falta valor para \(flag)") }; return args[i] }
while i < args.count {
    let a = args[i]
    switch a {
    case "--paper": s.paper = ["a4": .a4, "letter": .letter, "a5": .a5, "same": .sameAsSource][next(a)] ?? s.paper
    case "--margin": s.margin = Double(next(a)) ?? s.margin
    case "--min-scale": s.minScale = Double(next(a)) ?? s.minScale
    case "--answer": s.answerSpace = AnswerSpace(rawValue: next(a)) ?? s.answerSpace
    case "--label": s.labelTemplate = next(a); s.labelEnabled = true
    case "--no-label": s.labelEnabled = false
    case "--label-pos": s.labelPosition = LabelPosition(rawValue: next(a)) ?? s.labelPosition
    case "--pattern": s.customPattern = next(a)
    case "--ocr": s.ocr = OCRMode(rawValue: next(a)) ?? s.ocr
    case "--original": s.originalAction = ["move": .moveToDocuments, "documents": .moveToDocuments, "trash": .trash, "keep": .keep][next(a)] ?? s.originalAction
    case "--suffix": s.outputNaming = .suffix; s.outputSuffix = next(a)
    case "--lang": s.language = AppLanguage(rawValue: next(a)) ?? s.language; Lang.forced = s.language
    case "--reset": SettingsStore.save(Settings()); print("Ajustes restablecidos."); exit(0)
    case "--help", "-h": print(usage); exit(0)
    default: files.append(a)
    }
    i += 1
}

func line(_ r: SplitReport) {
    print("Patrón: \(r.pattern)\(r.usedOCR ? " (OCR)" : "") | \(r.exerciseCount) ejercicios | páginas \(r.sourcePages) → \(r.outputPages)")
    for row in r.rows {
        print(String(format: "  %2d  pág.origen %@  escala %.2f  hojas %d  ocupado %d%%%@", row.n,
                     row.sourcePages.map(String.init).joined(separator: ","), row.scale, row.outPages, row.usedPercent,
                     row.flagged ? "   <-- REVISAR" : ""))
    }
}

do {
    switch cmd {
    case "--version", "version": print("splitexercises 1.0.0")
    case "selftest":
        let r = SelfTest.run(); print(r.log); exit(r.ok ? 0 : 1)
    case "install":
        // El ejecutable real vive dentro de SplitExercises.app/Contents/Resources/splitexercises (brew enlaza a él).
        var u = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        if !u.path.contains(".app/") { u = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]).resolvingSymlinksInPath() }
        guard let r = u.path.range(of: ".app/") else { fail("No encuentro SplitExercises.app junto a este ejecutable (¿compilaste solo la CLI?)") }
        let appPath = String(u.path[..<r.lowerBound]) + ".app"
        // En /Applications: en macOS 27, Bartender no consigue colocar el icono de la barra de menús de las apps que se
        // ejecutan desde ~/Applications. Solo si /Applications no se puede escribir se usa ~/Applications.
        let fm = FileManager.default
        let userCopy = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/SplitExercises.app")
        let dest = fm.isWritableFile(atPath: "/Applications") ? URL(fileURLWithPath: "/Applications/SplitExercises.app") : userCopy
        if dest.path == userCopy.path { print("Aviso: no se puede escribir en /Applications; se instala en ~/Applications (Bartender podría no mostrar el icono).") }
        let lsr = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        func run(_ exe: String, _ a: [String]) throws { let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = a; try p.run(); p.waitUntilExit() }
        if appPath != dest.path {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: dest)
            try fm.copyItem(atPath: appPath, toPath: dest.path)
        }
        // La copia antigua en ~/Applications (instalaciones anteriores) sobra: se quita para que no haya dos.
        if dest.path != userCopy.path, fm.fileExists(atPath: userCopy.path) {
            try? run(lsr, ["-u", userCopy.path])
            try? fm.removeItem(at: userCopy)
        }
        try run(lsr, ["-f", dest.path])
        try run("/usr/bin/open", [dest.path])
        print("SplitExercises instalada en \(dest.path)")
    case "settings":
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(data: try e.encode(s), encoding: .utf8)!)
    case "dump":
        guard let f = files.first else { fail(usage) }
        print(try Debug.dump(URL(fileURLWithPath: f), page: files.count > 1 ? (Int(files[1]) ?? 1) : 1, settings: s))
    case "normalize":
        try Debug.normalize(URL(fileURLWithPath: files[0]), to: URL(fileURLWithPath: files[1]))
    case "analyze":
        guard !files.isEmpty else { fail(usage) }
        for f in files { let a = try Splitter.analyze(URL(fileURLWithPath: f), settings: s); print("\(f): \(a.exercises) ejercicios (patrón \(a.pattern)\(a.usedOCR ? ", OCR" : ""))") }
    case "generate":
        guard files.count == 2 else { fail(usage) }
        line(try Splitter.generate(URL(fileURLWithPath: files[0]), to: URL(fileURLWithPath: files[1]), settings: s))
    case "split":
        guard !files.isEmpty else { fail(usage) }
        for f in files {
            let o = try Splitter.split(URL(fileURLWithPath: f), settings: s)
            line(o.report)
            print("Resultado: \(o.resultURL.path)")
            if let od = o.originalURL { print("Original:  \(od.path)") }
        }
    case "undo":
        let e = try Splitter.undo()
        print("Deshecho: \(e.originalHome) restaurado.")
    default: print(usage)
    }
} catch {
    fail("Error: \(error.localizedDescription)")
}
