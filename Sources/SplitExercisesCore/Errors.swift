import Foundation

public enum SplitExercisesError: LocalizedError {
    case cannotOpen(String)
    case encrypted(String)
    case noMarkers(String)
    case invalidPattern(String)
    case writeFailed(String)
    case emptyResult
    case nothingToUndo

    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let f): return tr("No se puede abrir «\(f)» como PDF.", "Can't open “\(f)” as a PDF.")
        case .encrypted(let f): return tr("«\(f)» está protegido con contraseña.", "“\(f)” is password protected.")
        case .noMarkers(let f): return tr("No encuentro ejercicios numerados en «\(f)». Prueba un patrón propio en Ajustes → Detección.",
                                          "No numbered exercises found in “\(f)”. Try a custom pattern in Settings → Detection.")
        case .invalidPattern(let p): return tr("El patrón «\(p)» no es una expresión regular válida.", "“\(p)” is not a valid regular expression.")
        case .writeFailed(let m): return tr("No se pudo escribir el PDF: \(m)", "Couldn't write the PDF: \(m)")
        case .emptyResult: return tr("El resultado quedó vacío; no se ha tocado el original.", "The result was empty; the original was not touched.")
        case .nothingToUndo: return tr("No hay nada que deshacer.", "Nothing to undo.")
        }
    }
}
