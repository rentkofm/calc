import SwiftUI

enum FractalKind: String, CaseIterable, Identifiable {
    case mandelbrot = "Mandelbrot", julia = "Julia", burningShip = "Burning Ship"
    case tricorn = "Tricorn", multibrot = "Multibrot"
    var id: String { rawValue }

    var defaultCenter: CGPoint {
        switch self {
        case .mandelbrot: return CGPoint(x: -0.5, y: 0)
        case .burningShip: return CGPoint(x: -0.5, y: -0.5)
        default: return .zero
        }
    }
    static let defaultScale: CGFloat = 110
    /// Degree of the iterated map, used for smooth coloring.
    var degree: Double { self == .multibrot ? 3 : 2 }
}

enum FractalPalette: String, CaseIterable, Identifiable {
    case classic = "Classic", fire = "Fire", ocean = "Ocean", ultraviolet = "Ultraviolet"
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
        }
    }
}

struct FractalParams {
    var kind: FractalKind
    var palette: FractalPalette
    var center: CGPoint
    var scale: CGFloat
    var maxIter: Int
    var juliaC: (re: Double, im: Double)
}

enum FractalRenderer {
    static func render(_ p: FractalParams, size: CGSize, cell: CGFloat) -> CGImage? {
        let cx = Double(p.center.x), cy = Double(p.center.y), s = Double(p.scale)
        let hw = Double(size.width) / 2, hh = Double(size.height) / 2
        let k = p.palette.coefficients
        let twoPi = 2 * Double.pi
        return Raster.image(size: size, cell: cell) { sx, sy in
            let mu = escape(p, x: cx + (sx - hw) / s, y: cy - (sy - hh) / s)
            guard mu >= 0 else { return (0, 0, 0) }
            let t = mu * 0.035
            func channel(_ i: Int) -> UInt8 {
                let v = k.a[i] + k.b[i] * cos(twoPi * (k.c[i] * t + k.d[i]))
                return UInt8(min(max(v, 0), 1) * 255)
            }
            return (channel(0), channel(1), channel(2))
        }
    }

    /// Smooth escape time, or -1 for points that never escape.
    static func escape(_ p: FractalParams, x: Double, y: Double) -> Double {
        var zr: Double, zi: Double, cr: Double, ci: Double
        if p.kind == .julia {
            (zr, zi, cr, ci) = (x, y, p.juliaC.re, p.juliaC.im)
        } else {
            (zr, zi, cr, ci) = (0, 0, x, y)
        }
        if p.kind == .mandelbrot {
            // Skip the main cardioid and period-2 bulb.
            let q = (x - 0.25) * (x - 0.25) + y * y
            if q * (q + (x - 0.25)) < 0.25 * y * y || (x + 1) * (x + 1) + y * y < 0.0625 { return -1 }
        }
        var i = 0
        var m = 0.0
        while i < p.maxIter {
            let r2 = zr * zr, i2 = zi * zi
            m = r2 + i2
            if m > 256 { break }
            switch p.kind {
            case .mandelbrot, .julia:
                zi = 2 * zr * zi + ci
                zr = r2 - i2 + cr
            case .burningShip:
                let a = abs(zr), b = abs(zi)
                zi = 2 * a * b + ci
                zr = a * a - b * b + cr
            case .tricorn:
                zi = -2 * zr * zi + ci
                zr = r2 - i2 + cr
            case .multibrot:
                let nr = zr * (r2 - 3 * i2) + cr
                zi = zi * (3 * r2 - i2) + ci
                zr = nr
            }
            i += 1
        }
        if i >= p.maxIter { return -1 }
        return Double(i) + 1 - log2(0.5 * log(m)) / log2(p.kind.degree)
    }
}

struct FractalView: View {
    private static let juliaPresets: [(re: Double, im: Double)] = [
        (-0.8, 0.156), (-0.4, 0.6), (0.285, 0.01), (-0.70176, -0.3842), (0.355, 0.355), (-0.835, -0.2321), (0, 1),
    ]

    @Environment(\.appAccent) private var accent
    @Environment(\.displayScale) private var displayScale

    @State private var kind: FractalKind = .mandelbrot
    @State private var palette: FractalPalette = .classic
    @State private var juliaIndex = 0
    @State private var detail = 150.0
    @State private var center = FractalKind.mandelbrot.defaultCenter
    @State private var scale = FractalKind.defaultScale
    @State private var size = CGSize(width: 320, height: 320)
    @State private var image: CGImage?
    @State private var renderTask: Task<Void, Never>?
    @State private var renderID = 0
    @State private var dragOrigin: CGPoint?
    @State private var scaleOrigin: CGFloat?
    @State private var inertia = Inertia()

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
        let zoomBoost = 60 * max(0, log2(Double(scale / FractalKind.defaultScale)))
        return min(Int(detail + zoomBoost), 5000)
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
        var cx: Double, cy: Double, scale: Double
        var size: CGSize
    }

    private var renderKey: RenderKey {
        RenderKey(kind: kind, palette: palette, juliaIndex: juliaIndex, detail: detail,
                  cx: Double(center.x), cy: Double(center.y), scale: Double(scale), size: size)
    }

    /// A quick low-res frame right away, then a native-resolution one once things settle.
    private func refresh() {
        renderTask?.cancel()
        renderID += 1
        let id = renderID
        var quick = params
        quick.maxIter = min(quick.maxIter, 200)
        let (full, sz, ds) = (params, size, displayScale)
        image = FractalRenderer.render(quick, size: sz, cell: 5)
        renderTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            let cell = Raster.cell(for: sz, displayScale: ds)
            let hi = await Task.detached(priority: .userInitiated) {
                FractalRenderer.render(full, size: sz, cell: cell)
            }.value
            if Task.isCancelled { return }
            await MainActor.run { if id == renderID { image = hi } }
        }
    }

    private func reset() {
        inertia.stop()
        center = kind.defaultCenter
        scale = FractalKind.defaultScale
    }

    // MARK: Views

    private var canvas: some View {
        ZStack {
            Color.black
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            }
        }
        .frame(minHeight: 220)
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
        .overlay(alignment: .bottomLeading) {
            Text("\(formatNumber(Double(scale / FractalKind.defaultScale), digits: 3))× · \(maxIter) iterations")
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
                    if dragOrigin == nil { inertia.stop(); dragOrigin = center }
                    let o = dragOrigin ?? center
                    center = CGPoint(x: o.x - v.translation.width / scale,
                                     y: o.y + v.translation.height / scale)
                }
                .onEnded { v in
                    dragOrigin = nil
                    inertia.start(velocity: v.velocity) { dx, dy in
                        center.x -= CGFloat(dx) / scale
                        center.y += CGFloat(dy) / scale
                    }
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { v in
                    if scaleOrigin == nil { inertia.stop(); scaleOrigin = scale }
                    scale = min(max((scaleOrigin ?? scale) * v.magnification, 20), 1e13)
                }
                .onEnded { _ in scaleOrigin = nil }
        )
        .onTapGesture(count: 2) { withAnimation(.smooth) { reset() } }
        .onTapGesture { inertia.stop() }
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
                Spacer()
                if kind == .julia {
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
            }
            HStack(spacing: 12) {
                Text("Detail").foregroundStyle(.secondary)
                Slider(value: $detail, in: 50...1000, step: 10)
            }
            Text("Drag to pan · pinch to zoom · double-tap to reset")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
