import AppKit

/// Entrada de «Servicios» de macOS (clic derecho → Servicios → Dividir ejercicios con ExSplit).
final class ServiceProvider: NSObject {
    weak var delegate: AppDelegate?

    @objc(splitFiles:userData:error:)
    func splitFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        DispatchQueue.main.async { [weak self] in self?.delegate?.handle(urls) }
    }
}
