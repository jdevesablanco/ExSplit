import Foundation
import SplitExercisesCore
import SwiftUI

/// SwiftUI también define `Settings` (escena): fijamos cuál es el nuestro.
typealias Settings = SplitExercisesCore.Settings

/// Estado local para vistas SwiftUI sin usar `@State` (en los SDK recientes es un macro que exige Xcode completo).
final class Local<T>: ObservableObject {
    @Published var v: T
    init(_ v: T) { self.v = v }
}

enum AppInfo {
    static let version = "1.0.1"
    static let repoURL = "https://github.com/jdevesablanco/SplitExercises"
}

extension PaperSize {
    var title: String {
        switch self {
        case .a4: return "A4"
        case .letter: return "Letter"
        case .a5: return "A5"
        case .sameAsSource: return tr("Igual que el original", "Same as source")
        }
    }
}
extension AnswerSpace {
    var title: String {
        switch self {
        case .blank: return tr("En blanco", "Blank")
        case .lines: return tr("Rayas", "Ruled")
        case .grid: return tr("Cuadrícula", "Grid")
        case .dots: return tr("Puntos", "Dots")
        }
    }
}
extension LabelPosition {
    var title: String {
        switch self {
        case .topLeft: return tr("Arriba izquierda", "Top left")
        case .topCenter: return tr("Arriba centro", "Top center")
        case .topRight: return tr("Arriba derecha", "Top right")
        case .bottomLeft: return tr("Abajo izquierda", "Bottom left")
        case .bottomCenter: return tr("Abajo centro", "Bottom center")
        case .bottomRight: return tr("Abajo derecha", "Bottom right")
        }
    }
}
extension OriginalAction {
    /// La subcarpeta junto al PDF ya no se ofrece en la interfaz (los ajustes antiguos con ella pasan a «Documentos»).
    static var visibleCases: [OriginalAction] { allCases.filter { $0 != .moveToFolder } }
    var title: String {
        switch self {
        case .moveToFolder: return tr("Moverlo a una subcarpeta nueva", "Move it to a new subfolder")
        case .moveToDocuments: return tr("Moverlo a Documentos/SplitExercises", "Move it to Documents/SplitExercises")
        case .trash: return tr("Mandarlo a la Papelera", "Move it to the Trash")
        case .keep: return tr("Dejarlo donde está", "Leave it where it is")
        }
    }
}
extension OutputNaming {
    var title: String {
        switch self {
        case .sameAsOriginal: return tr("Mismo nombre que el original", "Same name as the original")
        case .suffix: return tr("Añadir un sufijo al nombre", "Add a suffix to the name")
        }
    }
}
extension OCRMode {
    var title: String {
        switch self {
        case .auto: return tr("Automático (solo si el PDF es escaneado)", "Automatic (only for scanned PDFs)")
        case .always: return tr("Siempre", "Always")
        case .never: return tr("Nunca", "Never")
        }
    }
}
