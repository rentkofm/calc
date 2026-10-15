import SwiftUI
import Observation

enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

let languageOptions: [(code: String, name: String)] = [
    ("en-US", "English (US)"), ("en-GB", "English (UK)"), ("es-ES", "Español"),
    ("fr-FR", "Français"), ("de-DE", "Deutsch"), ("it-IT", "Italiano"),
    ("pt-BR", "Português"), ("ja-JP", "日本語"), ("ko-KR", "한국어"), ("zh-CN", "中文"),
]

let accentPresets = ["#0A84FF", "#5E5CE6", "#BF5AF2", "#FF375F", "#FF453A", "#FF9F0A", "#30D158", "#40C8E0"]

@MainActor @Observable
final class AppSettings {
    @ObservationIgnored private let defaults = UserDefaults.standard

    var theme: ThemeChoice { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    var accentHex: String { didSet { defaults.set(accentHex, forKey: "accent") } }
    var textSize: Double { didSet { defaults.set(textSize, forKey: "textSize") } }
    var languageCode: String { didSet { defaults.set(languageCode, forKey: "lang") } }
    var saveHistory: Bool { didSet { defaults.set(saveHistory, forKey: "saveHistory") } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }

    init() {
        let d = UserDefaults.standard
        theme = ThemeChoice(rawValue: d.string(forKey: "theme") ?? "") ?? .system
        accentHex = d.string(forKey: "accent") ?? accentPresets[0]
        textSize = d.object(forKey: "textSize") as? Double ?? 30
        let preferred = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        languageCode = d.string(forKey: "lang")
            ?? (languageOptions.contains { $0.code == preferred } ? preferred : "en-US")
        saveHistory = d.object(forKey: "saveHistory") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
    }

    var accent: Color { Color(hex: accentHex) }

    func tap() {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }

    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
