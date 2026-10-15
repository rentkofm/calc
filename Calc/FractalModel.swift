import SwiftUI

enum FractalCategory: String, CaseIterable, Identifiable {
    case mandelbrot = "Mandelbrot", ships = "Ships", newton = "Newton"
    case transcendental = "Transcendental", chaos = "Chaos", geometric = "Geometric", threeD = "3D"
    case custom = "Custom"
    var id: String { rawValue }
    var kinds: [FractalKind] { FractalKind.allCases.filter { $0.category == self } }
}

/// How a fractal gets onto the screen.
enum RenderStyle {
    case raster      // evaluated per pixel
    case accumulate  // millions of points splatted into a density buffer
    case vector      // drawn as paths
    case ray3D       // ray-marched
}

enum FractalColoring: String, CaseIterable, Identifiable {
    case smooth = "Smooth", distance = "Distance", orbitTrap = "Orbit Trap"
    case triangle = "Triangle", curvature = "Curvature"
    var id: String { rawValue }
}

struct SliderSpec {
    var label: String
    var range: ClosedRange<Double>
    var step: Double
    var defaultValue: Double
}

enum FractalKind: String, CaseIterable, Identifiable {
    // Mandelbrot family
    case mandelbrot = "Mandelbrot", julia = "Julia", tricorn = "Tricorn", multibrot = "Multibrot"
    case quartic = "Quartic", quintic = "Quintic", fracPower = "Fractional Power", celtic = "Celtic"
    case perpendicular = "Perpendicular", phoenix = "Phoenix", inverse = "Inverse", lambda = "Lambda"
    case magnet = "Magnet", magnet2 = "Magnet II"
    // Ships
    case burningShip = "Burning Ship", cubicShip = "Cubic Ship", burningJulia = "Burning Julia"
    // Newton and friends
    case newton = "Newton z³", newton4 = "Newton z⁴", newton5 = "Newton z⁵", newtonChaos = "Newton Chaos"
    case halley = "Halley", nova = "Nova"
    // Transcendental
    case sine = "Sine", cosine = "Cosine", exponential = "Exponential", collatz = "Collatz", gamma = "Gamma"
    // Chaos
    case lyapunov = "Lyapunov", buddhabrot = "Buddhabrot", nebulabrot = "Nebulabrot"
    case clifford = "Clifford", deJong = "de Jong", henon = "Hénon", lorenz = "Lorenz"
    // Geometric
    case carpet = "Carpet", sierpinski = "Sierpinski", cantorDust = "Cantor Dust", vicsek = "Vicsek"
    case hilbert = "Hilbert", peano = "Peano", dragon = "Dragon Curve", levy = "Lévy C", koch = "Koch Snowflake"
    case fern = "Barnsley Fern", pythagoras = "Pythagoras Tree", apollonian = "Apollonian"
    case lPlant = "Fractal Plant", lTree = "Bush", lArrowhead = "Arrowhead"
    // 3D
    case mandelbulb = "Mandelbulb", mandelbox = "Mandelbox"
    // Morph between Mandelbrot and Julia, with its own exponent and coefficient
    case custom = "Custom"

    var id: String { rawValue }

    var category: FractalCategory {
        switch self {
        case .mandelbrot, .julia, .tricorn, .multibrot, .quartic, .quintic, .fracPower, .celtic,
             .perpendicular, .phoenix, .inverse, .lambda, .magnet, .magnet2:
            return .mandelbrot
        case .burningShip, .cubicShip, .burningJulia:
            return .ships
        case .newton, .newton4, .newton5, .newtonChaos, .halley, .nova:
            return .newton
        case .sine, .cosine, .exponential, .collatz, .gamma:
            return .transcendental
        case .lyapunov, .buddhabrot, .nebulabrot, .clifford, .deJong, .henon, .lorenz:
            return .chaos
        case .carpet, .sierpinski, .cantorDust, .vicsek, .hilbert, .peano, .dragon, .levy, .koch,
             .fern, .pythagoras, .apollonian, .lPlant, .lTree, .lArrowhead:
            return .geometric
        case .mandelbulb, .mandelbox:
            return .threeD
        case .custom:
            return .custom
        }
    }

    var style: RenderStyle {
        switch self {
        case .buddhabrot, .nebulabrot, .clifford, .deJong, .henon, .lorenz, .fern, .dragon, .levy, .koch:
            return .accumulate
        case .hilbert, .peano, .pythagoras, .apollonian, .lPlant, .lTree, .lArrowhead:
            return .vector
        case .mandelbulb, .mandelbox:
            return .ray3D
        default:
            return .raster
        }
    }

    // MARK: Viewport

    var defaultCenter: Center {
        switch self {
        case .mandelbrot, .celtic: return Center(x: -0.5, y: 0)
        case .burningShip: return Center(x: -0.5, y: -0.5)
        case .perpendicular: return Center(x: -0.25, y: 0)
        case .carpet, .sierpinski, .cantorDust, .vicsek, .hilbert, .peano: return Center(x: 0.5, y: 0.5)
        case .lambda, .magnet2: return Center(x: 1.5, y: 0)
        case .magnet: return Center(x: 1, y: 0)
        case .lyapunov: return Center(x: 3, y: 3)
        case .buddhabrot, .nebulabrot: return Center(x: 0, y: -0.5)
        case .lorenz: return Center(x: 0, y: 25)
        case .fern: return Center(x: 0, y: 5)
        case .dragon: return Center(x: 0.4, y: 0.25)
        case .levy: return Center(x: 0.5, y: 0.2)
        case .koch: return Center(x: 0.5, y: 0.43)
        case .pythagoras: return Center(x: 0, y: 2.2)
        case .custom: return Center(x: -0.25, y: 0)
        default: return Center(x: 0, y: 0)
        }
    }

    var defaultScale: CGFloat {
        switch self {
        case .carpet, .sierpinski, .cantorDust, .vicsek, .hilbert, .peano: return 300
        case .phoenix: return 150
        case .lambda: return 80
        case .magnet: return 60
        case .magnet2: return 55
        case .collatz: return 40
        case .gamma: return 60
        case .lyapunov: return 85
        case .buddhabrot, .nebulabrot: return 130
        case .clifford: return 60
        case .deJong: return 80
        case .lorenz: return 6.5
        case .fern: return 48
        case .dragon: return 200
        case .levy: return 180
        case .koch: return 200
        case .pythagoras: return 60
        case .apollonian: return 160
        case .lPlant, .lTree, .lArrowhead: return 400
        case .custom: return 100
        case .mandelbulb, .mandelbox: return 1
        default: return 110
        }
    }

    var minScale: CGFloat { defaultScale / 50 }

    /// Mandelbrot and Julia can zoom essentially without limit (arbitrary-precision reference orbit +
    /// perturbation). Everything else iterates in plain doubles, which run out of precision around 1e13.
    var supportsDeepZoom: Bool { self == .mandelbrot || self == .julia }
    var maxScale: CGFloat { supportsDeepZoom ? 1e300 : 1e13 }

    // MARK: Math

    /// Degree of the iterated map, used for smooth coloring.
    var degree: Double {
        switch self {
        case .multibrot, .cubicShip: return 3
        case .quartic: return 4
        case .quintic: return 5
        default: return 2
        }
    }

    /// How quickly the palette cycles with the iteration count.
    var colorFrequency: Double {
        switch self {
        case .carpet, .sierpinski, .cantorDust, .vicsek, .nova: return 0.12
        case .sine, .cosine, .exponential, .collatz, .gamma: return 0.08
        default: return 0.035
        }
    }

    /// Kinds that run the shared z → f(z) + c loop, and so can use the alternative coloring modes.
    var supportsColoring: Bool {
        switch self {
        case .mandelbrot, .julia, .tricorn, .multibrot, .quartic, .quintic, .fracPower, .celtic,
             .perpendicular, .phoenix, .inverse, .lambda, .burningShip, .cubicShip, .burningJulia, .custom:
            return true
        default:
            return false
        }
    }

    var supportsDistance: Bool { self == .mandelbrot || self == .julia }
    var usesJuliaConstant: Bool { self == .julia || self == .burningJulia }

    /// Escape-time kinds need more iterations the deeper you go.
    var usesZoomBoost: Bool {
        switch self {
        case .newton, .newton4, .newton5, .newtonChaos, .halley, .lyapunov: return false
        default: return style == .raster && detailSpec != nil
        }
    }

    // MARK: Controls

    var detailSpec: SliderSpec? {
        switch self {
        case .newton, .newton4, .newton5, .newtonChaos, .halley:
            return SliderSpec(label: "Detail", range: 20...200, step: 10, defaultValue: 60)
        case .lyapunov:
            return SliderSpec(label: "Detail", range: 40...1000, step: 10, defaultValue: 120)
        case .buddhabrot, .nebulabrot:
            return SliderSpec(label: "Iterations", range: 100...3000, step: 50, defaultValue: 500)
        case .mandelbulb:
            return SliderSpec(label: "Iterations", range: 4...20, step: 1, defaultValue: 10)
        case .mandelbox:
            return SliderSpec(label: "Iterations", range: 6...24, step: 1, defaultValue: 12)
        case .lPlant:
            return SliderSpec(label: "Depth", range: 1...6, step: 1, defaultValue: 5)
        case .lTree:
            return SliderSpec(label: "Depth", range: 1...5, step: 1, defaultValue: 4)
        case .lArrowhead:
            return SliderSpec(label: "Depth", range: 1...9, step: 1, defaultValue: 7)
        case .pythagoras:
            return SliderSpec(label: "Depth", range: 3...18, step: 1, defaultValue: 11)
        case .carpet, .sierpinski, .cantorDust, .vicsek, .clifford, .deJong, .henon, .lorenz,
             .dragon, .levy, .koch, .fern, .hilbert, .peano, .apollonian:
            return nil
        default:
            return SliderSpec(label: "Detail", range: 50...1000, step: 10, defaultValue: 150)
        }
    }

    var powerSpec: SliderSpec? {
        switch self {
        case .fracPower: return SliderSpec(label: "Power", range: 1.2...8, step: 0.1, defaultValue: 2.5)
        case .mandelbulb: return SliderSpec(label: "Power", range: 2...12, step: 0.1, defaultValue: 8)
        case .mandelbox: return SliderSpec(label: "Scale", range: -3...3.5, step: 0.05, defaultValue: 2)
        case .pythagoras: return SliderSpec(label: "Angle", range: 15...75, step: 1, defaultValue: 45)
        case .custom: return SliderSpec(label: "Power", range: 1.2...8, step: 0.05, defaultValue: 2)
        default: return nil
        }
    }

    var variantLabel: String {
        switch self {
        case .lyapunov: return "Sequence"
        case .lorenz: return "View"
        default: return "Preset"
        }
    }

    var variantNames: [String] {
        switch self {
        case .clifford, .deJong: return ["A", "B", "C", "D"]
        case .henon: return ["Classic", "Wide", "Dense"]
        case .lorenz: return ["X–Z", "X–Y", "Y–Z"]
        case .lyapunov: return ["AB", "AABAB", "BBBBBBAAAAAA", "ABBBAAB"]
        default: return []
        }
    }

    /// Distance of the 3D camera from its target at the default view.
    var defaultDistance: Double { self == .mandelbox ? 14 : 3 }
}

// MARK: - Palettes

enum FractalPalette: String, CaseIterable, Identifiable {
    case deepBlue = "Deep Blue", accent = "Accent", classic = "Classic", fire = "Fire", ocean = "Ocean"
    case ultraviolet = "Ultraviolet", forest = "Forest", mono = "Mono"
    var id: String { rawValue }

    /// Cosine palette: a + b·cos(2π(c·t + d)) per channel.
    var coefficients: (a: [Double], b: [Double], c: [Double], d: [Double]) {
        switch self {
        case .classic: return ([0.5, 0.5, 0.5], [0.5, 0.5, 0.5], [1, 1, 1], [0, 0.33, 0.67])
        case .fire: return ([0.5, 0.5, 0.5], [0.5, 0.5, 0.5], [1, 0.7, 0.4], [0, 0.15, 0.2])
        case .ocean: return ([0.8, 0.5, 0.4], [0.2, 0.4, 0.2], [2, 1, 1], [0, 0.25, 0.25])
        case .ultraviolet: return ([0.5, 0.5, 0.5], [0.5, 0.5, 0.5], [2, 1, 0], [0.5, 0.2, 0.25])
        case .forest: return ([0.2, 0.5, 0.2], [0.2, 0.4, 0.2], [1, 1, 1], [0, 0.1, 0.2])
        case .mono: return ([0.5, 0.5, 0.5], [0.5, 0.5, 0.5], [1, 1, 1], [0, 0, 0])
        case .deepBlue, .accent: return ([0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]) // gradient palettes, see below
        }
    }

    /// The look from the classic zoom videos: black → deep blue → white glow at the boundary,
    /// repeating in log-scale bands so the filaments keep their contrast.
    private static let deepBlueStops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0.00, 0.00, 0.00),
        (0.30, 0.00, 0.00, 0.28),
        (0.55, 0.02, 0.04, 0.78),
        (0.75, 0.35, 0.50, 1.00),
        (0.90, 0.80, 0.88, 1.00),
        (1.00, 1.00, 1.00, 1.00),
    ]

    /// The app's accent color as RGB (0...1); set by the fractal view before it renders.
    static var accentRGB: (Double, Double, Double) = (1.0, 0.584, 0.0)

    var isGradient: Bool { self == .deepBlue || self == .accent }

    /// Same shape as Deep Blue, built from the accent color: black → dark → full color → pale tint → white.
    private var stops: [(t: Double, r: Double, g: Double, b: Double)] {
        guard self == .accent else { return Self.deepBlueStops }
        let (r, g, b) = Self.accentRGB
        func tint(_ k: Double) -> (Double, Double, Double) { (r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k) }
        let a = tint(0.45), z = tint(0.82)
        return [
            (0.00, 0.00, 0.00, 0.00),
            (0.30, r * 0.28, g * 0.28, b * 0.28),
            (0.55, r * 0.80, g * 0.80, b * 0.80),
            (0.75, a.0, a.1, a.2),
            (0.90, z.0, z.1, z.2),
            (1.00, 1.00, 1.00, 1.00),
        ]
    }

    private func gradient(_ t: Double, brightness: Double) -> (UInt8, UInt8, UInt8) {
        let u = t - floor(t)
        let stops = self.stops
        var i = 0
        while i < stops.count - 2 && u > stops[i + 1].t { i += 1 }
        let a = stops[i], b = stops[i + 1]
        let f = (u - a.t) / (b.t - a.t)
        func ch(_ x: Double, _ y: Double) -> UInt8 { UInt8(min(max((x + (y - x) * f) * brightness, 0), 1) * 255) }
        return (ch(a.r, b.r), ch(a.g, b.g), ch(a.b, b.b))
    }

    /// Color for a smooth escape-time value.
    func color(forMu mu: Double, frequency: Double, brightness: Double = 1) -> (UInt8, UInt8, UInt8) {
        if isGradient {
            // Wider bands, and an ease-out curve so more of each band is pale: the glow fades to white
            // over a larger area as the boundary gets closer.
            let v = max(0, log2(max(mu, 0) + 1) - 1) / 5.5
            return gradient(pow(v - floor(v), 0.65), brightness: brightness)
        }
        return color(at: mu * frequency, brightness: brightness)
    }

    func color(at t: Double, brightness: Double = 1) -> (UInt8, UInt8, UInt8) {
        if isGradient { return gradient(t, brightness: brightness) }
        let k = coefficients
        func channel(_ i: Int) -> UInt8 {
            let v = k.a[i] + k.b[i] * cos(2 * Double.pi * (k.c[i] * t + k.d[i]))
            return UInt8(min(max(v * brightness, 0), 1) * 255)
        }
        return (channel(0), channel(1), channel(2))
    }

    func swiftUIColor(at t: Double) -> Color {
        let c = color(at: t)
        return Color(red: Double(c.0) / 255, green: Double(c.1) / 255, blue: Double(c.2) / 255)
    }

    /// Bright colors that read well as lines and fills on a black background.
    func lineColors(_ n: Int) -> [Color] {
        (0..<max(n, 2)).map { i in
            let f = Double(i) / Double(max(n - 1, 1))
            return swiftUIColor(at: isGradient ? 0.5 + 0.48 * f : f)
        }
    }
}

struct FractalParams {
    var kind: FractalKind
    var palette: FractalPalette
    var coloring: FractalColoring = .smooth
    var center: Center
    var scale: CGFloat
    var maxIter: Int
    var juliaC: (re: Double, im: Double)
    var power: Double = 2
    var variant: Int = 0
    var rotation: Double = 0
    var morph: Double = 0   // Custom: 0 = Mandelbrot … 1 = Julia
    var coef: Double = 1    // Custom: coefficient on the power term
}
