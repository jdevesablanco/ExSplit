import SwiftUI
import AppKit

/// Modo de verificación visual: `EXSPLIT_SNAPSHOT=/ruta ExSplit` renderiza las pantallas del onboarding a PNG y sale (sin ventanas).
enum Snapshot {
    @MainActor static func run(model: SettingsModel, dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let cases: [(String, AnyView)] = [
            ("paso1", AnyView(OnboardingView(model: model, startStep: 0) {})),
            ("paso2", AnyView(OnboardingView(model: model, startStep: 1) {})),
            ("paso3", AnyView(OnboardingView(model: model, startStep: 2) {})),
            ("final", AnyView(OnboardingView(model: model, startStep: 2, startDone: true) {})),
        ]
        for (name, v) in cases {
            let r = ImageRenderer(content: v.background(Color(nsColor: .windowBackgroundColor)))
            r.scale = 2
            guard let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
    }
}
