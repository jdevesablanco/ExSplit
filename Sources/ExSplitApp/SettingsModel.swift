import Foundation
import ExSplitCore

/// Ajustes observables: cada cambio se guarda en disco al instante.
final class SettingsModel: ObservableObject {
    static let shared = SettingsModel()
    var onChange: ((Settings, Settings) -> Void)?
    @Published var s: Settings {
        didSet {
            guard s != oldValue else { return }
            SettingsStore.save(s)
            onChange?(oldValue, s)
        }
    }
    private init() { s = SettingsStore.load() }
}
