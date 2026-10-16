import SwiftUI

/// Gray–Scott reaction–diffusion on a torus. Two chemicals U and V: U feeds V, V converts U and decays.
/// The explicit update runs row-parallel over raw buffers so thousands of steps per second are practical.
private final class GrayScott {
    private(set) var w = 0
    private(set) var h = 0
    private var u: UnsafeMutablePointer<Float>
    private var v: UnsafeMutablePointer<Float>
    private var u2: UnsafeMutablePointer<Float>
    private var v2: UnsafeMutablePointer<Float>

    init() {
        u = .allocate(capacity: 1); v = .allocate(capacity: 1); u2 = .allocate(capacity: 1); v2 = .allocate(capacity: 1)
    }

    deinit { u.deallocate(); v.deallocate(); u2.deallocate(); v2.deallocate() }

    func setup(width: Int, height: Int) {
        u.deallocate(); v.deallocate(); u2.deallocate(); v2.deallocate()
        w = width; h = height
        let n = w * h
        u = .allocate(capacity: n); v = .allocate(capacity: n); u2 = .allocate(capacity: n); v2 = .allocate(capacity: n)
        reseed()
    }

    func reseed() {
        let n = w * h
        for i in 0..<n { u[i] = 1; v[i] = 0; u2[i] = 1; v2[i] = 0 }
        var rng = SplitMix64(state: UInt64(Date().timeIntervalSince1970 * 1000))
        for _ in 0..<12 {
            paint(Int(rng.nextDouble() * Double(w)), Int(rng.nextDouble() * Double(h)), radius: 4)
        }
    }

    func paint(_ cx: Int, _ cy: Int, radius: Int) {
        guard w > 0 else { return }
        for dy in -radius...radius {
            for dx in -radius...radius where dx * dx + dy * dy <= radius * radius {
                let x = ((cx + dx) % w + w) % w, y = ((cy + dy) % h + h) % h
                u[y * w + x] = 0.5; v[y * w + x] = 1
            }
        }
    }

    func step(feed f: Float, kill k: Float, iterations: Int) {
        guard w > 2, h > 2 else { return }
        let w = self.w, h = self.h
        for _ in 0..<iterations {
            let U = u, V = v, U2 = u2, V2 = v2
            DispatchQueue.concurrentPerform(iterations: h) { y in
                let row = y * w
                let up = ((y + h - 1) % h) * w, dn = ((y + 1) % h) * w
                for x in 0..<w {
                    let l = x == 0 ? w - 1 : x - 1, r = x == w - 1 ? 0 : x + 1
                    let c = U[row + x], vc = V[row + x]
                    let lapU = 0.2 * (U[row + l] + U[row + r] + U[up + x] + U[dn + x])
                        + 0.05 * (U[up + l] + U[up + r] + U[dn + l] + U[dn + r]) - c
                    let lapV = 0.2 * (V[row + l] + V[row + r] + V[up + x] + V[dn + x])
                        + 0.05 * (V[up + l] + V[up + r] + V[dn + l] + V[dn + r]) - vc
                    let uvv = c * vc * vc
                    U2[row + x] = min(1, max(0, c + (1.0 * lapU - uvv + f * (1 - c))))
                    V2[row + x] = min(1, max(0, vc + (0.5 * lapV + uvv - (f + k) * vc)))
                }
            }
            swap(&u, &u2); swap(&v, &v2)
        }
    }

    func image(hue: Double) -> CGImage? {
        guard w > 0 else { return nil }
        let lut: [(UInt8, UInt8, UInt8)] = (0..<256).map { i in
            let t = Double(i) / 255
            return PendulumPalette.hsv(hue + 0.12 * t, 0.85 - 0.6 * t * t, 0.06 + 0.94 * pow(t, 0.8))
        }
        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        for i in 0..<(w * h) {
            let c = lut[Int(min(1, v[i] * 2.4) * 255)]
            rgba[i * 4] = c.0; rgba[i * 4 + 1] = c.1; rgba[i * 4 + 2] = c.2
        }
        return Raster.cgImage(width: w, height: h, rgba: rgba)
    }
}

struct TuringView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent

    private struct Preset: Identifiable {
        let name: String
        let f: Double
        let k: Double
        var id: String { name }
    }

    private static let presets: [Preset] = [
        Preset(name: "Mitosis", f: 0.0367, k: 0.0649), Preset(name: "Coral", f: 0.0545, k: 0.0620),
        Preset(name: "Solitons", f: 0.0300, k: 0.0620), Preset(name: "Labyrinth", f: 0.0290, k: 0.0570),
        Preset(name: "Holes", f: 0.0390, k: 0.0580),
    ]

    @State private var sim = GrayScott()
    @State private var image: CGImage?
    @State private var feed = 0.0367
    @State private var kill = 0.0649
    @State private var perFrame = 8.0
    @State private var resolution = 128
    @State private var playing = true
    @State private var size: CGSize = .zero
    @State private var frames = 0

    private func rebuild() {
        guard size.width > 0 else { return }
        let aspect = Double(size.height / size.width)
        sim.setup(width: resolution, height: max(32, min(320, Int(Double(resolution) * aspect))))
        image = sim.image(hue: ExColor.hue(of: accent))
        frames = 0
    }

    var body: some View {
        ExToolPage(info: ["tool.grayscott", "tool.turing"]) {
            ZStack {
                Color.black
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable().interpolation(.medium)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                TimelineView(.animation(paused: !active || !playing)) { tl in
                    Color.clear.onChange(of: tl.date) { _, _ in
                        sim.step(feed: Float(feed), kill: Float(kill), iterations: Int(perFrame))
                        image = sim.image(hue: ExColor.hue(of: accent))
                        frames += Int(perFrame)
                    }
                }
                .allowsHitTesting(false)
            }
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard size.width > 0 else { return }
                        sim.paint(Int(Double(v.location.x / size.width) * Double(sim.w)),
                                  Int(Double(v.location.y / size.height) * Double(sim.h)), radius: 3)
                    }
            )
        } controls: {
            ExTransport(playing: $playing, onReset: { sim.reseed(); frames = 0 })
            Menu {
                ForEach(Self.presets) { p in Button(p.name) { feed = p.f; kill = p.k; sim.reseed(); frames = 0 } }
            } label: {
                Label("Presets", systemImage: "list.bullet").frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glass)
            ExParamRow(title: "Feed F", value: $feed, range: 0.01...0.08, step: 0.0005, format: "%.4f")
            ExParamRow(title: "Kill k", value: $kill, range: 0.04...0.07, step: 0.0005, format: "%.4f")
            ExParamRow(title: "Steps", value: $perFrame, range: 1...24, step: 1, format: "%.0f/frame")
            Picker("Resolution", selection: $resolution) {
                Text("Fast").tag(96); Text("Normal").tag(128); Text("Fine").tag(192)
            }
            .pickerStyle(.segmented)
            Text("\(frames) steps. Drag on the picture to add more V. Presets are starting points from the classic F–k map; patterns depend on the seed.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: size) { _, _ in rebuild() }
        .onChange(of: resolution) { _, _ in rebuild() }
        .onAppear { rebuild() }
    }
}
