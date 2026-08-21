import Foundation
import Combine

protocol SettingsManagerProtocol {
    var appearance: AppearanceOption { get }
    var fontSize: Double { get }
    func setAppearance(_ option: AppearanceOption)
    func setFontSize(_ size: Double)
}

enum AppearanceOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

final class SettingsManager: SettingsManagerProtocol {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let appearance = "com.codeforge.settings.appearance"
        static let fontSize = "com.codeforge.settings.fontSize"
    }

    var appearance: AppearanceOption {
        guard let raw = defaults.string(forKey: Keys.appearance),
              let option = AppearanceOption(rawValue: raw) else {
            return .system
        }
        return option
    }

    var fontSize: Double {
        let value = defaults.double(forKey: Keys.fontSize)
        return value > 0 ? value : 16.0
    }

    func setAppearance(_ option: AppearanceOption) {
        defaults.set(option.rawValue, forKey: Keys.appearance)
    }

    func setFontSize(_ size: Double) {
        defaults.set(size, forKey: Keys.fontSize)
    }
}
