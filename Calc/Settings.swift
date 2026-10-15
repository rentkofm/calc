import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case orange, blue, indigo, purple, pink, red, green, mint, teal, graphite
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .graphite: return Color(white: 0.45)
        }
    }
}

private struct AppAccentKey: EnvironmentKey {
    static let defaultValue: Color = .orange
}

extension EnvironmentValues {
    var appAccent: Color {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// Soft accent-colored backdrop so the glass has something to refract.
struct AppBackground: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color(.systemBackground)
            Circle()
                .fill(accent.opacity(scheme == .dark ? 0.50 : 0.38))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: -130, y: -260)
            Circle()
                .fill(accent.opacity(scheme == .dark ? 0.30 : 0.22))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 150, y: 300)
        }
        .ignoresSafeArea()
    }
}
