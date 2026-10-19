import Foundation
import CoreGraphics

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto, es, en
    public var id: String { rawValue }
}

public enum Lang {
    /// Idioma elegido por el usuario (la app y la CLI lo fijan al arrancar). `.auto` = el del sistema.
    nonisolated(unsafe) public static var forced: AppLanguage = .auto
}

/// Texto bilingüe mínimo: español o inglés según el ajuste de idioma (o el del sistema).
public func tr(_ es: String, _ en: String) -> String {
    switch Lang.forced {
    case .es: return es
    case .en: return en
    case .auto: return (Locale.preferredLanguages.first ?? "en").hasPrefix("es") ? es : en
    }
}

// MARK: - Enums

public enum PaperSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case a4, letter, a5, sameAsSource
    public var id: String { rawValue }
    public func size(source: CGSize) -> CGSize {
        switch self {
        case .a4: return CGSize(width: 595.28, height: 841.89)
        case .letter: return CGSize(width: 612, height: 792)
        case .a5: return CGSize(width: 419.53, height: 595.28)
        case .sameAsSource: return source
        }
    }
}

public enum LabelPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight
    public var id: String { rawValue }
}

public enum AnswerSpace: String, Codable, CaseIterable, Identifiable, Sendable {
    case blank, lines, grid, dots
    public var id: String { rawValue }
}

public enum OriginalAction: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Mueve el original a una subcarpeta (por defecto `_Original`).
    case moveToFolder
    /// Manda el original a la papelera.
    case trash
    /// Deja el original donde está (el resultado lleva un sufijo en el nombre).
    case keep
    public var id: String { rawValue }
}

public enum OutputNaming: String, Codable, CaseIterable, Identifiable, Sendable {
    case sameAsOriginal, suffix
    public var id: String { rawValue }
}

public enum OCRMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto, always, never
    public var id: String { rawValue }
}

// MARK: - Settings

/// Todas las opciones configurables. Se guardan en JSON y son compartidas por la app y la CLI.
public struct Settings: Codable, Equatable, Sendable {
    // Maquetación
    public var paper: PaperSize = .a4
    public var margin: Double = 36
    public var minScale: Double = 0.85
    public var answerSpace: AnswerSpace = .blank
    // Etiqueta
    public var labelEnabled: Bool = true
    /// Vacío = plantilla por defecto del idioma («Ejercicio {n}» / «Exercise {n}»).
    public var labelTemplate: String = ""
    public var labelContinuation: String = "(cont.)"
    public var labelPosition: LabelPosition = .bottomLeft
    public var labelFontSize: Double = 7
    public var labelGray: Double = 0.6
    // Detección
    /// Vacío = automático (N. / N) / Ejercicio N / Problema N…). Si no, expresión regular con el número en el grupo 1.
    public var customPattern: String = ""
    public var ocr: OCRMode = .auto
    public var ocrLanguages: [String] = ["es-ES", "en-US"]
    // Salida
    public var outputNaming: OutputNaming = .sameAsOriginal
    /// Vacío = sufijo por defecto del idioma.
    public var outputSuffix: String = ""
    public var originalAction: OriginalAction = .moveToFolder
    public var originalFolderName: String = "ExSplit"
    public var hideOriginalFolder: Bool = false
    // Comportamiento
    public var askBeforeEachRun: Bool = false
    public var notify: Bool = true
    public var revealResult: Bool = false
    public var openResult: Bool = false
    // App
    public var language: AppLanguage = .auto
    public var showMenuBarIcon: Bool = true
    public var launchAtLogin: Bool = true
    public var onboardingDone: Bool = false

    public init() {}

    public var effectiveLabelTemplate: String { labelTemplate.isEmpty ? tr("Ejercicio {n}", "Exercise {n}") : labelTemplate }
    public var effectiveSuffix: String { outputSuffix.isEmpty ? tr(" (ejercicios)", " (exercises)") : outputSuffix }

    public init(from decoder: Decoder) throws {
        // Decodificación tolerante: las claves que falten (versiones antiguas) toman el valor por defecto.
        self.init()
        let c = try decoder.container(keyedBy: Keys.self)
        func get<T: Decodable>(_ k: Keys, _ v: inout T) { if let x = try? c.decodeIfPresent(T.self, forKey: k) { v = x } }
        get(.paper, &paper); get(.margin, &margin); get(.minScale, &minScale); get(.answerSpace, &answerSpace)
        get(.labelEnabled, &labelEnabled); get(.labelTemplate, &labelTemplate); get(.labelContinuation, &labelContinuation)
        get(.labelPosition, &labelPosition); get(.labelFontSize, &labelFontSize); get(.labelGray, &labelGray)
        get(.customPattern, &customPattern); get(.ocr, &ocr); get(.ocrLanguages, &ocrLanguages)
        get(.outputNaming, &outputNaming); get(.outputSuffix, &outputSuffix); get(.originalAction, &originalAction)
        get(.originalFolderName, &originalFolderName); get(.hideOriginalFolder, &hideOriginalFolder)
        get(.askBeforeEachRun, &askBeforeEachRun); get(.notify, &notify); get(.revealResult, &revealResult); get(.openResult, &openResult)
        get(.language, &language); get(.showMenuBarIcon, &showMenuBarIcon); get(.launchAtLogin, &launchAtLogin); get(.onboardingDone, &onboardingDone)
    }

    enum Keys: String, CodingKey {
        case paper, margin, minScale, answerSpace, labelEnabled, labelTemplate, labelContinuation, labelPosition
        case labelFontSize, labelGray, customPattern, ocr, ocrLanguages, outputNaming, outputSuffix, originalAction
        case originalFolderName, hideOriginalFolder, askBeforeEachRun, notify, revealResult, openResult
        case language, showMenuBarIcon, launchAtLogin, onboardingDone
    }
}

// MARK: - Persistencia

public enum SettingsStore {
    public static var directory: URL {
        // EXSPLIT_CONFIG_DIR permite aislar los ajustes (pruebas, CI, instalaciones portátiles).
        if let d = ProcessInfo.processInfo.environment["EXSPLIT_CONFIG_DIR"], !d.isEmpty { return URL(fileURLWithPath: d, isDirectory: true) }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ExSplit", isDirectory: true)
    }
    public static var fileURL: URL { directory.appendingPathComponent("settings.json") }

    public static func load() -> Settings {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return s
    }

    public static func save(_ s: Settings) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? enc.encode(s) { try? d.write(to: fileURL, options: .atomic) }
    }
}
