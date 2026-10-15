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
    case orange, blue, indigo, purple, pink, red, green, mint, teal, graphite, custom
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
        case .custom: return .orange // resolved with the stored hex, see `resolved(customHex:)`
        }
    }
}

extension AccentChoice {
    static var presets: [AccentChoice] { allCases.filter { $0 != .custom } }

    func resolved(customHex: String) -> Color {
        self == .custom ? Color(hex: customHex) : color
    }
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
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

/// Deterministic hash-based randomness so stars and buildings keep their places between frames.
private func unitRandom(_ a: Int, _ b: Int = 0) -> Double {
    var z = UInt64(truncatingIfNeeded: a &* 7919 &+ b &* 104729 &+ 0x9E3779B97F4A7C15)
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    z ^= z >> 31
    return Double(z % 1_000_000) / 1_000_000
}

/// Soft accent-colored backdrop with a night sky of twinkling stars and a city skyline whose windows light up in dark mode.
struct AppBackground: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var scheme
    @AppStorage("starDensity") private var starDensity = 0.5
    @AppStorage("starTwinkle") private var starTwinkle = 0.5

    var body: some View {
        let night = scheme == .dark
        ZStack {
            Color(.systemBackground)
            Circle()
                .fill(accent.opacity(night ? 0.50 : 0.38))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: -130, y: -260)
            Circle()
                .fill(accent.opacity(night ? 0.30 : 0.22))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 150, y: 300)
            if night { stars.transition(.opacity) }
            skyline(night: night)
        }
        .animation(.smooth(duration: 0.6), value: night)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var stars: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: starTwinkle <= 0 || starDensity <= 0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let count = Int(starDensity * 450)
                guard count > 0 else { return }
                for i in 0..<count {
                    let x = unitRandom(i, 1) * size.width
                    let y = unitRandom(i, 2) * size.height * 0.85
                    let base = 0.35 + 0.65 * unitRandom(i, 3)
                    let r = 0.5 + 1.3 * unitRandom(i, 4) * unitRandom(i, 4)
                    let speed = 0.8 + 2.6 * unitRandom(i, 5)
                    let wave = 0.5 + 0.5 * sin(t * speed + unitRandom(i, 6) * 6.283)
                    let alpha = base * (1 - starTwinkle * 0.85 * wave)
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                    if r > 1.3 {
                        ctx.fill(Path(ellipseIn: rect.insetBy(dx: -r, dy: -r)), with: .color(.white.opacity(alpha * 0.15)))
                    }
                }
            }
        }
    }

    private func skyline(night: Bool) -> some View {
        Canvas { ctx, size in
            let maxH = min(size.height * 0.24, 260)
            var x: CGFloat = -4
            var i = 0
            while x < size.width {
                let w = 22 + CGFloat(unitRandom(i, 11)) * 34
                let tall = unitRandom(i, 12)
                let h = maxH * (0.25 + 0.75 * CGFloat(tall * tall * 0.6 + tall * 0.4))
                let rect = CGRect(x: x, y: size.height - h, width: w, height: h)
                let body = night ? Color(white: 0.05, opacity: 0.92) : Color(white: 0.45, opacity: 0.22)
                ctx.fill(Path(rect), with: .color(body))
                if unitRandom(i, 13) > 0.7 {        // antenna
                    var mast = Path()
                    mast.move(to: CGPoint(x: rect.midX, y: rect.minY))
                    mast.addLine(to: CGPoint(x: rect.midX, y: rect.minY - 14))
                    ctx.stroke(mast, with: .color(body), lineWidth: 1.5)
                }
                if night {
                    let cols = max(Int((w - 6) / 7), 1), rows = max(Int((h - 8) / 9), 1)
                    for r in 0..<rows {
                        for c in 0..<cols where unitRandom(i * 131 + r, c + 50) > 0.45 {
                            let wx = rect.minX + 4 + CGFloat(c) * 7
                            let wy = rect.minY + 6 + CGFloat(r) * 9
                            let win = CGRect(x: wx, y: wy, width: 3.5, height: 5)
                            let warm = unitRandom(i * 131 + r, c + 99) > 0.2
                            let color = warm ? Color(red: 1, green: 0.84, blue: 0.5) : accent
                            ctx.fill(Path(win.insetBy(dx: -2, dy: -2)), with: .color(color.opacity(0.14)))
                            ctx.fill(Path(win), with: .color(color.opacity(0.95)))
                        }
                    }
                }
                x += w + CGFloat(unitRandom(i, 14)) * 3
                i += 1
            }
        }
    }
}
