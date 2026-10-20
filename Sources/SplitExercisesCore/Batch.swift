import Foundation

/// Resultado de procesar un archivo (o de analizarlo). Es lo que imprime la CLI con `--json`.
public struct BatchEntry: Codable {
    public enum Status: String, Codable { case split, analyzed, skipped, failed }
    public var status: Status
    public var path: String
    public var exercises: Int?
    public var pattern: String?
    public var ocr: Bool?
    /// Solo en `analyze`: si `split` lo procesaría al apuntarle una carpeta.
    public var splittable: Bool?
    public var result: String?
    public var original: String?
    public var reason: String?
    /// Informe detallado (solo para la salida de texto; no se serializa).
    public var report: SplitReport?

    enum CodingKeys: String, CodingKey { case status, path, exercises, pattern, ocr, splittable, result, original, reason }
}

/// Procesa varios archivos y/o carpetas con los ajustes del usuario. Lo usa la CLI (y, por tanto, las IAs): el criterio de qué
/// PDFs son hojas de ejercicios vive aquí, no en quien llama.
public enum Batch {
    /// En una carpeta solo se divide lo que tiene al menos esto ejercicios reconocidos. Un archivo dado explícitamente se procesa siempre.
    public static let minExercisesInFolder = 2

    struct Candidate { let url: URL; let fromFolder: Bool }

    static func canonical(_ path: String) -> String { URL(fileURLWithPath: path).resolvingSymlinksInPath().path }

    static func expand(_ paths: [String], recursive: Bool) -> [Candidate] {
        let fm = FileManager.default
        var out: [Candidate] = []
        var seen = Set<String>()
        func add(_ u: URL, _ folder: Bool) { if seen.insert(canonical(u.path)).inserted { out.append(Candidate(url: u, fromFolder: folder)) } }
        for p in paths {
            let u = URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: u.path, isDirectory: &isDir), isDir.boolValue else { add(u, false); continue }
            var opts: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            if !recursive { opts.insert(.skipsSubdirectoryDescendants) }
            let en = fm.enumerator(at: u, includingPropertiesForKeys: nil, options: opts)
            var found: [URL] = []
            while let f = en?.nextObject() as? URL { if f.pathExtension.lowercased() == "pdf" { found.append(f) } }
            found.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            found.forEach { add($0, true) }
        }
        return out
    }

    /// Por qué un PDF encontrado dentro de una carpeta no se toca (nil = candidato).
    static func skipReason(_ u: URL, history: Set<String>, settings s: Settings) -> String? {
        let fname = s.originalFolderName.isEmpty ? "SplitExercises" : s.originalFolderName
        let parent = u.deletingLastPathComponent()
        if parent.lastPathComponent == fname {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            if parent.deletingLastPathComponent().path == docs?.path || s.originalAction == .moveToFolder {
                return tr("está en la carpeta de originales", "it is in the originals folder")
            }
        }
        if history.contains(canonical(u.path)) { return tr("ya dividido por SplitExercises", "already split by SplitExercises") }
        let name = u.deletingPathExtension().lastPathComponent
        for suf in [s.effectiveSuffix, " (ejercicios)", " (exercises)"] where name.hasSuffix(suf) {
            return tr("parece un resultado ya dividido", "looks like an already split result")
        }
        return nil
    }

    /// Archivos que SplitExercises ya procesó: los resultados y los originales que se quedaron en su sitio (`Original: dejar`) mientras
    /// el resultado siga existiendo. Evita volver a dividir lo mismo al repetir el comando sobre una carpeta.
    static func historyResults() -> Set<String> {
        let fm = FileManager.default
        let h = History.load()
        var out = Set(h.map { canonical($0.result) })
        for e in h where fm.fileExists(atPath: e.result) { out.insert(canonical(e.originalHome)) }
        return out
    }

    // MARK: analyze

    /// Cuenta ejercicios sin escribir nada. Con carpetas indica además qué PDFs dividiría `split`.
    public static func analyze(_ paths: [String], recursive: Bool, settings s: Settings) -> [BatchEntry] {
        let hist = historyResults()
        var out: [BatchEntry] = []
        for c in expand(paths, recursive: recursive) {
            let p = c.url.path
            if c.fromFolder, let why = skipReason(c.url, history: hist, settings: s) {
                out.append(BatchEntry(status: .skipped, path: p, splittable: false, reason: why)); continue
            }
            do {
                let a = try Splitter.analyze(c.url, settings: s)
                let ok = !c.fromFolder || a.exercises >= minExercisesInFolder
                out.append(BatchEntry(status: .analyzed, path: p, exercises: a.exercises, pattern: a.pattern, ocr: a.usedOCR, splittable: ok,
                                      reason: ok ? nil : tr("pocos ejercicios reconocidos", "too few exercises recognised")))
            } catch {
                if c.fromFolder {
                    out.append(BatchEntry(status: .analyzed, path: p, exercises: 0, splittable: false, reason: tr("sin ejercicios reconocibles", "no recognisable exercises")))
                } else {
                    out.append(BatchEntry(status: .failed, path: p, reason: error.localizedDescription))
                }
            }
        }
        return out
    }

    // MARK: split

    /// Divide archivos y carpetas aplicando los ajustes guardados (qué hacer con el original, nombre, etc.). En carpetas se salta lo que
    /// no son hojas de ejercicios; un fallo en un archivo no detiene a los demás.
    public static func split(_ paths: [String], recursive: Bool, settings s: Settings,
                             progress: ((BatchEntry) -> Void)? = nil) -> [BatchEntry] {
        let hist = historyResults()
        var out: [BatchEntry] = []
        func emit(_ e: BatchEntry) { out.append(e); progress?(e) }
        for c in expand(paths, recursive: recursive) {
            let p = c.url.path
            if c.fromFolder {
                if let why = skipReason(c.url, history: hist, settings: s) { emit(BatchEntry(status: .skipped, path: p, reason: why)); continue }
                let n = (try? Splitter.analyze(c.url, settings: s))?.exercises ?? 0
                if n < minExercisesInFolder {
                    emit(BatchEntry(status: .skipped, path: p, exercises: n, reason: tr("sin ejercicios reconocibles", "no recognisable exercises"))); continue
                }
            }
            do {
                let o = try Splitter.split(c.url, settings: s)
                emit(BatchEntry(status: .split, path: p, exercises: o.report.exerciseCount, pattern: o.report.pattern, ocr: o.report.usedOCR,
                                result: o.resultURL.path, original: o.originalURL?.path, report: o.report))
            } catch {
                emit(BatchEntry(status: .failed, path: p, reason: error.localizedDescription))
            }
        }
        return out
    }
}
