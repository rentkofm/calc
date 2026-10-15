import SwiftUI

enum FractalKind: String, CaseIterable, Identifiable {
    case mandelbrot = "Mandelbrot", julia = "Julia", burningShip = "Burning Ship"
    case tricorn = "Tricorn", multibrot = "Multibrot", quartic = "Quartic"
    case celtic = "Celtic", perpendicular = "Perpendicular", phoenix = "Phoenix"
    case newton = "Newton", carpet = "Carpet", sierpinski = "Sierpinski"
    case quintic = "Quintic", cubicShip = "Cubic Ship", burningJulia = "Burning Julia"
    case lambda = "Lambda", magnet = "Magnet", inverse = "Inverse"
    case cantorDust = "Cantor Dust", vicsek = "Vicsek"
    var id: String { rawValue }

    var defaultCenter: Center {
        switch self {
        case .mandelbrot, .celtic: return Center(x: -0.5, y: 0)
        case .burningShip: return Center(x: -0.5, y: -0.5)
        case .perpendicular: return Center(x: -0.25, y: 0)
        case .carpet, .sierpinski, .cantorDust, .vicsek: return Center(x: 0.5, y: 0.5)
        case .lambda: return Center(x: 1.5, y: 0)
        case .magnet: return Center(x: 1, y: 0)
        default: return Center(x: 0, y: 0)
        }
    }

    /// Mandelbrot and Julia can zoom essentially without limit (arbitrary-precision reference orbit +
    /// perturbation). The others iterate in plain doubles, which run out of precision around 1e13.
    var supportsDeepZoom: Bool { self == .mandelbrot || self == .julia }
    var maxScale: CGFloat { supportsDeepZoom ? 1e300 : 1e13 }

    var defaultScale: CGFloat {
        switch self {
        case .carpet, .sierpinski, .cantorDust, .vicsek: return 300
        case .phoenix: return 150
        case .lambda: return 80
        case .magnet: return 60
        default: return 110
        }
    }

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
        case .carpet, .sierpinski, .cantorDust, .vicsek: return 0.12
        default: return 0.035
        }
    }

    /// Structural fractals have a fixed depth; no point scaling iterations with zoom.
    var isStructural: Bool { self == .carpet || self == .sierpinski || self == .cantorDust || self == .vicsek }

    var usesJuliaConstant: Bool { self == .julia || self == .burningJulia }
}

enum FractalPalette: String, CaseIterable, Identifiable {
    case deepBlue = "Deep Blue", classic = "Classic", fire = "Fire", ocean = "Ocean", ultraviolet = "Ultraviolet"
    case forest = "Forest", mono = "Mono"
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
        case .deepBlue: return ([0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]) // gradient palette, see below
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

    private func gradient(_ t: Double, brightness: Double) -> (UInt8, UInt8, UInt8) {
        let u = t - floor(t)
        let stops = Self.deepBlueStops
        var i = 0
        while i < stops.count - 2 && u > stops[i + 1].t { i += 1 }
        let a = stops[i], b = stops[i + 1]
        let f = (u - a.t) / (b.t - a.t)
        func ch(_ x: Double, _ y: Double) -> UInt8 { UInt8(min(max((x + (y - x) * f) * brightness, 0), 1) * 255) }
        return (ch(a.r, b.r), ch(a.g, b.g), ch(a.b, b.b))
    }

    /// Color for a smooth escape-time value.
    func color(forMu mu: Double, frequency: Double) -> (UInt8, UInt8, UInt8) {
        if self == .deepBlue {
            // Wider bands, and an ease-out curve so more of each band is pale: the glow fades to white
            // over a larger area as the boundary gets closer.
            let v = max(0, log2(max(mu, 0) + 1) - 1) / 5.5
            return gradient(pow(v - floor(v), 0.65), brightness: 1)
        }
        return color(at: mu * frequency)
    }

    func color(at t: Double, brightness: Double = 1) -> (UInt8, UInt8, UInt8) {
        if self == .deepBlue { return gradient(t, brightness: brightness) }
        let k = coefficients
        func channel(_ i: Int) -> UInt8 {
            let v = k.a[i] + k.b[i] * cos(2 * Double.pi * (k.c[i] * t + k.d[i]))
            return UInt8(min(max(v * brightness, 0), 1) * 255)
        }
        return (channel(0), channel(1), channel(2))
    }
}

struct FractalParams {
    var kind: FractalKind
    var palette: FractalPalette
    var center: Center
    var scale: CGFloat
    var maxIter: Int
    var juliaC: (re: Double, im: Double)
}

enum FractalRenderer {
    static func render(_ p: FractalParams, size: CGSize, cell: CGFloat) -> CGImage? {
        if p.kind.supportsDeepZoom && p.scale > 1e9 { return renderDeep(p, size: size, cell: cell) }
        let cx = p.center.doubleX, cy = p.center.doubleY, s = Double(p.scale)
        let hw = Double(size.width) / 2, hh = Double(size.height) / 2
        return Raster.image(size: size, cell: cell) { sx, sy in
            let x = cx + (sx - hw) / s, y = cy - (sy - hh) / s
            if p.kind == .newton { return newton(p, x: x, y: y) }
            let mu = escape(p, x: x, y: y)
            guard mu >= 0 else { return (0, 0, 0) }
            return p.palette.color(forMu: mu, frequency: p.kind.colorFrequency)
        }
    }

    /// Newton's method on z³ − 1: color by the root reached, darker the longer it took.
    static func newton(_ p: FractalParams, x: Double, y: Double) -> (UInt8, UInt8, UInt8) {
        let roots: [(Double, Double)] = [(1, 0), (-0.5, 0.8660254037844386), (-0.5, -0.8660254037844386)]
        var zr = x, zi = y
        for i in 0..<min(p.maxIter, 120) {
            let z2r = zr * zr - zi * zi, z2i = 2 * zr * zi
            let z3r = z2r * zr - z2i * zi, z3i = z2r * zi + z2i * zr
            // z -= (z³ − 1) / (3z²)
            let nr = z3r - 1, ni = z3i
            let dr = 3 * z2r, di = 3 * z2i
            let d = dr * dr + di * di
            if d == 0 { return (0, 0, 0) }
            zr -= (nr * dr + ni * di) / d
            zi -= (ni * dr - nr * di) / d
            for (k, r) in roots.enumerated() {
                let dx = zr - r.0, dy = zi - r.1
                if dx * dx + dy * dy < 1e-10 {
                    let brightness = max(0.25, 1 - Double(i) / 30)
                    return p.palette.color(at: Double(k) * 0.33 + 0.1, brightness: brightness)
                }
            }
        }
        return (0, 0, 0)
    }

    /// Smooth escape time, or -1 for points that never escape.
    static func escape(_ p: FractalParams, x: Double, y: Double) -> Double {
        switch p.kind {
        case .carpet, .cantorDust, .vicsek: return ternary(p.kind, x, y, p.maxIter)
        case .sierpinski: return sierpinski(x, y, p.maxIter)
        case .magnet: return magnet(x, y, p.maxIter)
        default: break
        }

        var zr = 0.0, zi = 0.0, cr = x, ci = y
        var pr = 0.0, pi = 0.0 // previous z, for Phoenix
        switch p.kind {
        case .julia, .burningJulia:
            (zr, zi, cr, ci) = (x, y, p.juliaC.re, p.juliaC.im)
        case .lambda:
            zr = 0.5
        case .inverse:
            let d = x * x + y * y
            if d == 0 { return -1 }
            (cr, ci) = (x / d, -y / d)
        case .phoenix:
            (zr, zi, cr, ci) = (x, y, 0.5667, 0)
        case .mandelbrot:
            // Skip the main cardioid and period-2 bulb.
            let q = (x - 0.25) * (x - 0.25) + y * y
            if q * (q + (x - 0.25)) < 0.25 * y * y || (x + 1) * (x + 1) + y * y < 0.0625 { return -1 }
        default:
            break
        }

        var i = 0
        var m = 0.0
        while i < p.maxIter {
            let r2 = zr * zr, i2 = zi * zi
            m = r2 + i2
            if m > 256 { break }
            switch p.kind {
            case .mandelbrot, .julia, .inverse:
                zi = 2 * zr * zi + ci
                zr = r2 - i2 + cr
            case .burningShip, .burningJulia:
                let a = abs(zr), b = abs(zi)
                zi = 2 * a * b + ci
                zr = a * a - b * b + cr
            case .cubicShip:
                let a = abs(zr), b = abs(zi)
                zi = b * (3 * a * a - b * b) + ci
                zr = a * (a * a - 3 * b * b) + cr
            case .quintic:
                let ar = r2 - i2, ai = 2 * zr * zi // z²
                let br = ar * ar - ai * ai, bi = 2 * ar * ai // z⁴
                let nr = br * zr - bi * zi + cr
                zi = br * zi + bi * zr + ci
                zr = nr
            case .lambda:
                // z ← c·z·(1 − z)
                let wr = zr - r2 + i2, wi = zi - 2 * zr * zi
                zr = cr * wr - ci * wi
                zi = cr * wi + ci * wr
            case .tricorn:
                zi = -2 * zr * zi + ci
                zr = r2 - i2 + cr
            case .multibrot:
                let nr = zr * (r2 - 3 * i2) + cr
                zi = zi * (3 * r2 - i2) + ci
                zr = nr
            case .quartic:
                let ar = r2 - i2, ai = 2 * zr * zi // z²
                zr = ar * ar - ai * ai + cr
                zi = 2 * ar * ai + ci
            case .celtic:
                let nr = abs(r2 - i2) + cr
                zi = 2 * zr * zi + ci
                zr = nr
            case .perpendicular:
                zi = -2 * abs(zr) * zi + ci
                zr = r2 - i2 + cr
            case .phoenix:
                let nr = r2 - i2 + cr - 0.5 * pr
                let ni = 2 * zr * zi - 0.5 * pi
                (pr, pi) = (zr, zi)
                (zr, zi) = (nr, ni)
            default:
                break
            }
            i += 1
        }
        if i >= p.maxIter { return -1 }
        return Double(i) + 1 - log2(0.5 * log(m)) / log2(p.kind.degree)
    }

    /// Base-3 self-similar sets (carpet, Cantor dust, Vicsek). Removed cells are colored by the level they appear at.
    private static func ternary(_ kind: FractalKind, _ x0: Double, _ y0: Double, _ maxIter: Int) -> Double {
        guard x0 >= 0, x0 < 1, y0 >= 0, y0 < 1 else { return -1 }
        var x = x0, y = y0
        for level in 0..<min(maxIter, 30) { // ×3 isn't exact in binary; deeper levels are noise
            x *= 3; y *= 3
            let ix = floor(x), iy = floor(y)
            let removed: Bool
            switch kind {
            case .cantorDust: removed = ix == 1 || iy == 1
            case .vicsek: removed = ix != 1 && iy != 1
            default: removed = ix == 1 && iy == 1 // carpet
            }
            if removed { return Double(level) }
            x -= ix; y -= iy
        }
        return -1
    }

    /// Magnet fractal (type I): z ← ((z² + c − 1) / (2z + c − 2))². Points that settle on 1 are inside.
    private static func magnet(_ cr: Double, _ ci: Double, _ maxIter: Int) -> Double {
        var zr = 0.0, zi = 0.0
        for i in 0..<maxIter {
            let nr = zr * zr - zi * zi + cr - 1, ni = 2 * zr * zi + ci
            let dr = 2 * zr + cr - 2, di = 2 * zi + ci
            let d = dr * dr + di * di
            if d == 0 { return -1 }
            let qr = (nr * dr + ni * di) / d, qi = (ni * dr - nr * di) / d
            zr = qr * qr - qi * qi
            zi = 2 * qr * qi
            let m = zr * zr + zi * zi
            if m > 256 { return Double(i) + 1 - log2(0.5 * log(m)) }
            if (zr - 1) * (zr - 1) + zi * zi < 1e-8 { return -1 }
        }
        return -1
    }

    /// Sierpinski triangle (gasket): the removed triangles are colored by level.
    private static func sierpinski(_ x0: Double, _ y0: Double, _ maxIter: Int) -> Double {
        guard x0 >= 0, x0 < 1, y0 >= 0, y0 < 1 else { return -1 }
        var x = x0, y = y0
        for level in 0..<min(maxIter, 50) { // ×2 is exact in binary
            x *= 2; y *= 2
            let ix = floor(x), iy = floor(y)
            if ix == 1 && iy == 1 { return Double(level) }
            x -= ix; y -= iy
        }
        return -1
    }
}

struct FractalView: View {
    private static let juliaPresets: [(re: Double, im: Double)] = [
        (-0.8, 0.156), (-0.4, 0.6), (0.285, 0.01), (-0.70176, -0.3842), (0.355, 0.355), (-0.835, -0.2321), (0, 1),
    ]

    @Environment(\.appAccent) private var accent
    @Environment(\.displayScale) private var displayScale

    @State private var kind: FractalKind = .mandelbrot
    @State private var palette: FractalPalette = .deepBlue
    @State private var juliaIndex = 0
    @State private var detail = 150.0
    @State private var zoomSpeed = 1.0 // doublings per second
    @State private var center: Center = FractalKind.mandelbrot.defaultCenter
    @State private var scale = FractalKind.mandelbrot.defaultScale
    @State private var size = CGSize(width: 320, height: 320)
    @State private var renderer = ProgressiveRenderer()
    @State private var dragOrigin: Center?
    @State private var scaleOrigin: CGFloat?
    @State private var inertia = Inertia()
    @State private var autoZoomTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 12) {
            canvas
            kindChips
            controls
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .onChange(of: renderKey) { refresh() }
        .onChange(of: kind) { reset() }
        .onAppear { refresh() }
    }

    // MARK: Rendering

    private var maxIter: Int {
        if kind.isStructural { return 50 }
        let zoomBoost = 60 * max(0, log2(Double(scale / kind.defaultScale)))
        return min(Int(detail + zoomBoost), 100_000)
    }

    private var params: FractalParams {
        FractalParams(kind: kind, palette: palette, center: center, scale: scale, maxIter: maxIter,
                      juliaC: Self.juliaPresets[juliaIndex])
    }

    private struct RenderKey: Equatable {
        var kind: FractalKind
        var palette: FractalPalette
        var juliaIndex: Int
        var detail: Double
        var center: Center
        var scale: Double
        var size: CGSize
    }

    private var renderKey: RenderKey {
        RenderKey(kind: kind, palette: palette, juliaIndex: juliaIndex, detail: detail,
                  center: center, scale: Double(scale), size: size)
    }

    private func refresh() {
        let full = params
        let sz = size
        renderer.request(viewport: Viewport(center: center, scale: Double(scale), size: sz),
                         displayScale: displayScale) { cell in
            var p = full
            if cell > 2 { p.maxIter = min(p.maxIter, 800) } // keep the in-motion frames quick
            return FractalRenderer.render(p, size: sz, cell: cell)
        }
    }

    // MARK: Motion

    private func stopMotion() {
        inertia.stop()
        autoZoomTask?.cancel()
        autoZoomTask = nil
    }

    private func reset() {
        stopMotion()
        center = kind.defaultCenter
        scale = kind.defaultScale
    }

    /// Zooms toward `point` at a constant exponential rate, easing the point to the middle of the view.
    private func startAutoZoom(at point: CGPoint) {
        stopMotion()
        let target = center.moved(dx: Double((point.x - size.width / 2) / scale),
                                  dy: -Double((point.y - size.height / 2) / scale))
        var screen = point
        Haptics.tap()
        autoZoomTask = Task { @MainActor in
            var last = ContinuousClock.now
            while !Task.isCancelled && scale < kind.maxScale {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                let now = ContinuousClock.now
                let dt = min(0.05, (now - last) / .seconds(1))
                last = now
                let ease = CGFloat(1 - exp(-3 * dt))
                screen.x += (size.width / 2 - screen.x) * ease
                screen.y += (size.height / 2 - screen.y) * ease
                scale *= CGFloat(pow(2, zoomSpeed * dt))
                center = target.moved(dx: -Double((screen.x - size.width / 2) / scale),
                                      dy: Double((screen.y - size.height / 2) / scale))
            }
            autoZoomTask = nil
        }
    }

    // MARK: Views

    private var canvas: some View {
        ZStack {
            Color.black
            ViewportImage(image: renderer.image, viewport: renderer.viewport,
                          center: center, scale: scale, size: size)
        }
        .frame(minHeight: 220)
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
        .overlay(alignment: .bottomLeading) {
            Text("\(formatNumber(Double(scale / kind.defaultScale), digits: 3))× · \(maxIter) iterations")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: Capsule())
                .padding(10)
                .allowsHitTesting(false)
        }
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in
                    if dragOrigin == nil { stopMotion(); dragOrigin = center }
                    let o = dragOrigin ?? center
                    center = o.moved(dx: -Double(v.translation.width / scale),
                                     dy: Double(v.translation.height / scale))
                }
                .onEnded { v in
                    dragOrigin = nil
                    inertia.start(velocity: v.velocity) { dx, dy in
                        center = center.moved(dx: -dx / Double(scale), dy: dy / Double(scale))
                    }
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { v in
                    if scaleOrigin == nil { stopMotion(); scaleOrigin = scale }
                    scale = min(max((scaleOrigin ?? scale) * v.magnification, 10), kind.maxScale)
                }
                .onEnded { _ in scaleOrigin = nil }
        )
        // Tap to stop coasting or auto-zoom; double-tap a point to zoom into it.
        .simultaneousGesture(
            SpatialTapGesture(count: 1).onEnded { _ in
                if inertia.running || autoZoomTask != nil { stopMotion() }
            }
        )
        .simultaneousGesture(
            SpatialTapGesture(count: 2).onEnded { value in startAutoZoom(at: value.location) }
        )
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(FractalKind.allCases) { k in
                        let selected = k == kind
                        Button {
                            kind = k
                        } label: {
                            Text(k.rawValue)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 38)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(selected ? .regular.tint(accent).interactive() : .regular.interactive(),
                                     in: Capsule())
                    }
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Palette", selection: $palette) {
                    ForEach(FractalPalette.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(accent)
                if kind.usesJuliaConstant {
                    Picker("c", selection: $juliaIndex) {
                        ForEach(Self.juliaPresets.indices, id: \.self) { i in
                            let c = Self.juliaPresets[i]
                            Text("c = \(formatNumber(c.re, digits: 5)) \(c.im < 0 ? "−" : "+") \(formatNumber(abs(c.im), digits: 5))i")
                                .tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accent)
                }
                Spacer()
                Button {
                    withAnimation(.smooth) { reset() }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            if !kind.isStructural {
                HStack(spacing: 12) {
                    Text("Detail").foregroundStyle(.secondary)
                    Slider(value: $detail, in: 50...1000, step: 10)
                }
            }
            HStack(spacing: 12) {
                Text("Auto-zoom").foregroundStyle(.secondary)
                Slider(value: $zoomSpeed, in: 0.25...5)
                Text("\(formatNumber(pow(2, zoomSpeed), digits: 3))×/s")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            Text("Double-tap a point to zoom into it · tap to stop")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
