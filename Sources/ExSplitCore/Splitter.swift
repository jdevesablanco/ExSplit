import Foundation
import PDFKit

public struct SplitOutcome: Sendable {
    public let report: SplitReport
    public let resultURL: URL
    /// Dónde acabó el original (nil si se dejó en su sitio o se mandó a la papelera).
    public let originalURL: URL?
    public let originalAction: OriginalAction
    public let historyID: UUID
}

public struct HistoryEntry: Codable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var originalHome: String      // ruta donde estaba el original
    public var originalNow: String?      // ruta donde está ahora (carpeta _Original / papelera)
    public var result: String
    public var action: OriginalAction
}

public enum Splitter {
    /// Solo analiza (sin escribir nada): útil para avisar "he encontrado N ejercicios".
    public static func analyze(_ url: URL, settings: Settings) throws -> (exercises: Int, pattern: String, usedOCR: Bool) {
        let (doc, plan) = try prepare(url, settings: settings)
        return (plan.exercises.count, plan.patternName, doc.usedOCR)
    }

    /// Abre y analiza el PDF. En modo automático, si el texto nativo no da ningún ejercicio (capa de texto rota, páginas
    /// rotadas…) reintenta con OCR antes de rendirse.
    static func prepare(_ url: URL, settings: Settings) throws -> (SourceDocument, Plan) {
        let doc = try SourceDocument(url: url, ocr: settings.ocr, languages: settings.ocrLanguages)
        var first: Plan?
        var firstError: Error?
        do { first = try Planner.make(doc, settings: settings) } catch { firstError = error }
        let weak = (first?.exercises.count ?? 0) < 2
        if weak, settings.ocr == .auto, !doc.usedOCR,
           let ocrDoc = try? SourceDocument(url: url, ocr: .always, languages: settings.ocrLanguages),
           let p2 = try? Planner.make(ocrDoc, settings: settings), p2.exercises.count > (first?.exercises.count ?? 0) {
            return (ocrDoc, p2)
        }
        if let p = first { return (doc, p) }
        throw firstError ?? ExSplitError.noMarkers(url.lastPathComponent)
    }

    /// Genera el PDF dividido en `output` sin tocar nada más (modo "solo generar").
    @discardableResult
    public static func generate(_ url: URL, to output: URL, settings: Settings) throws -> SplitReport {
        let (doc, plan) = try prepare(url, settings: settings)
        return try Renderer.render(doc, plan: plan, settings: settings, to: output)
    }

    /// Divide el PDF y aplica la política de salida (nombre, qué hacer con el original). Nunca pierde el original:
    /// primero genera en un temporal, comprueba que tiene páginas y solo entonces mueve cosas.
    public static func split(_ url: URL, settings s: Settings) throws -> SplitOutcome {
        let fm = FileManager.default
        let folder = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let tmp = folder.appendingPathComponent(".exsplit-\(UUID().uuidString.prefix(8)).pdf")
        defer { try? fm.removeItem(at: tmp) }

        let report = try generate(url, to: tmp, settings: s)

        var naming = s.outputNaming
        if s.originalAction == .keep { naming = .suffix }   // el original se queda: el resultado no puede llamarse igual

        var originalNow: URL?
        var dest: URL
        switch naming {
        case .suffix:
            dest = uniqueURL(folder.appendingPathComponent(name + s.effectiveSuffix + ".pdf"))
            switch s.originalAction {
            case .keep: break
            case .trash:
                var out: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &out)
            case .moveToFolder, .moveToDocuments:
                originalNow = try moveToOriginalFolder(url, folder: folder, settings: s)
            }
        case .sameAsOriginal:
            dest = url
            switch s.originalAction {
            case .trash:
                var out: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &out)
            default: // moveToFolder (keep ya se forzó a sufijo)
                originalNow = try moveToOriginalFolder(url, folder: folder, settings: s)
            }
        }
        try fm.moveItem(at: tmp, to: dest)

        let entry = HistoryEntry(id: UUID(), date: Date(), originalHome: url.path, originalNow: originalNow?.path,
                                 result: dest.path, action: s.originalAction)
        History.append(entry)
        return SplitOutcome(report: report, resultURL: dest, originalURL: originalNow, originalAction: s.originalAction, historyID: entry.id)
    }

    static func moveToOriginalFolder(_ url: URL, folder: URL, settings s: Settings) throws -> URL {
        let fm = FileManager.default
        let base = s.originalAction == .moveToDocuments ? (fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? folder) : folder
        let od = base.appendingPathComponent(s.originalFolderName.isEmpty ? "ExSplit" : s.originalFolderName, isDirectory: true)
        try fm.createDirectory(at: od, withIntermediateDirectories: true)
        let target = uniqueURL(od.appendingPathComponent(url.lastPathComponent))
        try fm.moveItem(at: url, to: target)
        return target
    }

    static func uniqueURL(_ u: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: u.path) else { return u }
        let base = u.deletingPathExtension().lastPathComponent, ext = u.pathExtension, dir = u.deletingLastPathComponent()
        var i = 2
        while true {
            let c = dir.appendingPathComponent("\(base) \(i)").appendingPathExtension(ext)
            if !fm.fileExists(atPath: c.path) { return c }
            i += 1
        }
    }

    /// Deshace una división: devuelve el original a su sitio y manda el resultado a la papelera.
    @discardableResult
    public static func undo(_ id: UUID? = nil) throws -> HistoryEntry {
        let fm = FileManager.default
        var all = History.load()
        guard let idx = id.flatMap({ i in all.firstIndex(where: { $0.id == i }) }) ?? (all.isEmpty ? nil : all.count - 1) else {
            throw ExSplitError.nothingToUndo
        }
        let e = all[idx]
        let result = URL(fileURLWithPath: e.result)
        if fm.fileExists(atPath: result.path) { var o: NSURL?; try fm.trashItem(at: result, resultingItemURL: &o) }
        if let now = e.originalNow, fm.fileExists(atPath: now) {
            try fm.moveItem(at: URL(fileURLWithPath: now), to: URL(fileURLWithPath: e.originalHome))
        } else if e.action == .trash {
            // el original está en la papelera: no sabemos dónde; avisamos al llamador dejándolo en el historial
            throw ExSplitError.writeFailed("El original está en la Papelera: recupéralo desde Finder (⌘Z o «Volver a poner»).")
        }
        all.remove(at: idx)
        History.save(all)
        return e
    }
}

public enum History {
    static var url: URL { SettingsStore.directory.appendingPathComponent("history.json") }

    public static func load() -> [HistoryEntry] {
        guard let d = try? Data(contentsOf: url) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode([HistoryEntry].self, from: d)) ?? []
    }

    static func save(_ a: [HistoryEntry]) {
        try? FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = [.prettyPrinted]
        if let d = try? enc.encode(a) { try? d.write(to: url, options: .atomic) }
    }

    static func append(_ e: HistoryEntry) {
        var a = load(); a.append(e)
        if a.count > 30 { a.removeFirst(a.count - 30) }
        save(a)
    }
}

public enum Debug {
    /// Vuelca las primeras líneas detectadas de una página (diagnóstico: `exsplit dump archivo.pdf [página]`).
    public static func dump(_ url: URL, page: Int = 1, settings: Settings) throws -> String {
        let doc = try SourceDocument(url: url, ocr: settings.ocr, languages: settings.ocrLanguages)
        guard page >= 1, page <= doc.pages.count else { return "página fuera de rango" }
        let p = doc.pages[page - 1]
        var out = "página \(page): \(p.size.width)x\(p.size.height) OCR=\(doc.usedOCR) líneas=\(p.lines.count)\n"
        for l in p.lines.prefix(25) {
            out += String(format: "  x=%6.1f y=%6.1f w=%6.1f h=%5.1f  %@\n", l.rect.minX, l.rect.minY, l.rect.width, l.rect.height, String(l.text.prefix(60)))
        }
        return out
    }
}

extension Debug {
    public static func normalize(_ url: URL, to out: URL) throws {
        guard let pk = PDFDocument(url: url), let d = SourceDocument.normalizedData(from: pk) else { throw ExSplitError.cannotOpen("normalizar") }
        try d.write(to: out)
    }
}
