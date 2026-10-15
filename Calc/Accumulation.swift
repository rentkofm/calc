import SwiftUI

// MARK: - Random numbers

struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

// MARK: - Plot mapping

/// Maps plane coordinates to indices in a density buffer for the current viewport.
struct PlotMap {
    let cx: Double, cy: Double, scale: Double
    let hw: Double, hh: Double
    let kx: Double, ky: Double
    let w: Int, h: Int
    let cosR: Double, sinR: Double

    init(center: Center, scale: Double, rotation: Double, size: CGSize, w: Int, h: Int) {
        cx = center.doubleX
        cy = center.doubleY
        cosR = cos(rotation)
        sinR = sin(rotation)
        self.scale = scale
        hw = Double(size.width) / 2
        hh = Double(size.height) / 2
        kx = Double(w) / Double(size.width)
        ky = Double(h) / Double(size.height)
        self.w = w
        self.h = h
    }

    /// `u` runs along the screen's x axis, `v` along its y axis (both in plane units).
    func index(u: Double, v: Double) -> Int? {
        let ox = (u - cx) * scale, oy = (v - cy) * scale
        let sx = (hw + ox * cosR + oy * sinR) * kx
        let sy = (hh - (-ox * sinR + oy * cosR)) * ky
        guard sx >= 0, sx < Double(w), sy >= 0, sy < Double(h) else { return nil }
        return Int(sy) * w + Int(sx)
    }
}

typealias AccumSampler = (_ map: PlotMap, _ seed: UInt64, _ hist: UnsafeMutablePointer<UInt32>) -> Void
typealias AccumColorizer = (_ hist: [UInt32], _ w: Int, _ h: Int) -> CGImage?

struct AccumSpec {
    var channels: Int
    var maxBatches: Int
    var sampler: AccumSampler
    var colorize: AccumColorizer
}

// MARK: - Renderer

/// Builds up a density image over many background batches, showing each intermediate result.
@Observable
final class AccumulationRenderer {
    private(set) var image: CGImage?
    private(set) var viewport = Viewport()

    private var generation = 0
    private var task: Task<Void, Never>?

    func clear() {
        generation += 1
        task?.cancel()
        image = nil
    }

    func start(viewport vp: Viewport, spec: AccumSpec) {
        generation += 1
        let gen = generation
        task?.cancel()

        let cell: CGFloat = 1
        let w = max(1, Int(vp.size.width / cell)), h = max(1, Int(vp.size.height / cell))
        let map = PlotMap(center: vp.center, scale: vp.scale, rotation: vp.rotation, size: vp.size, w: w, h: h)
        let n = w * h * spec.channels

        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(80)) // let a gesture settle before restarting
            var hist = [UInt32](repeating: 0, count: n)
            var batch = 0
            while !Task.isCancelled && batch < spec.maxBatches {
                let seed = UInt64(batch) &* 0x1234_5678_9ABC_DEF1 &+ UInt64(gen) &* 7919
                let part = await Task.detached(priority: .userInitiated) {
                    Self.runBatch(n: n, map: map, seed: seed, sampler: spec.sampler)
                }.value
                if Task.isCancelled { return }
                for i in 0..<n { hist[i] &+= part[i] }
                let img = spec.colorize(hist, w, h)
                guard let self, gen == self.generation else { return }
                self.image = img
                self.viewport = vp
                batch += 1
            }
        }
    }

    private static func runBatch(n: Int, map: PlotMap, seed: UInt64, sampler: AccumSampler) -> [UInt32] {
        let chunks = 8
        let sum = UnsafeMutablePointer<UInt32>.allocate(capacity: n)
        sum.initialize(repeating: 0, count: n)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: chunks) { c in
            var local = [UInt32](repeating: 0, count: n)
            local.withUnsafeMutableBufferPointer { buf in
                if let base = buf.baseAddress {
                    sampler(map, seed &+ UInt64(c) &* 0x9E37_79B9, base)
                }
            }
            lock.lock()
            for i in 0..<n { sum[i] &+= local[i] }
            lock.unlock()
        }
        let out = Array(UnsafeBufferPointer(start: sum, count: n))
        sum.deallocate()
        return out
    }
}

// MARK: - Specs for each kind

enum Accumulate {
    static func spec(for p: FractalParams) -> AccumSpec {
        switch p.kind {
        case .buddhabrot:
            return AccumSpec(channels: 1, maxBatches: 300,
                             sampler: buddha(limits: [max(50, Int(p.maxIter))]),
                             colorize: density(p.palette))
        case .nebulabrot:
            let r = max(100, p.maxIter)
            return AccumSpec(channels: 3, maxBatches: 300,
                             sampler: buddha(limits: [r, max(30, r / 5), max(10, r / 25)]),
                             colorize: rgb())
        case .clifford, .deJong, .henon, .lorenz:
            return AccumSpec(channels: 1, maxBatches: 60,
                             sampler: attractor(p.kind, variant: p.variant), colorize: density(p.palette))
        default:
            return AccumSpec(channels: 1, maxBatches: 40,
                             sampler: ifs(p.kind), colorize: density(p.palette))
        }
    }

    // MARK: Buddhabrot

    /// Plots the orbits of points that escape. With several limits (one per channel) it makes a Nebulabrot.
    private static func buddha(limits: [Int]) -> AccumSampler {
        let channels = limits.count
        let maxLimit = limits.max() ?? 100
        return { map, seed, hist in
            var rng = SplitMix64(state: seed)
            var orbR = [Double](repeating: 0, count: maxLimit + 1)
            var orbI = [Double](repeating: 0, count: maxLimit + 1)
            for _ in 0..<5000 {
                let cr = -2.0 + 3.0 * rng.nextDouble(), ci = -1.5 + 3.0 * rng.nextDouble()
                let q = (cr - 0.25) * (cr - 0.25) + ci * ci
                if q * (q + (cr - 0.25)) < 0.25 * ci * ci || (cr + 1) * (cr + 1) + ci * ci < 0.0625 { continue }
                var zr = 0.0, zi = 0.0, n = 0
                var escaped = false
                while n < maxLimit {
                    let nr = zr * zr - zi * zi + cr
                    zi = 2 * zr * zi + ci
                    zr = nr
                    orbR[n] = zr; orbI[n] = zi
                    n += 1
                    if zr * zr + zi * zi > 4 { escaped = true; break }
                }
                guard escaped, n > 3 else { continue }
                for ch in 0..<channels where n <= limits[ch] {
                    for k in 0..<n {
                        // The real axis runs vertically, which puts the "Buddha" upright.
                        if let idx = map.index(u: orbI[k], v: orbR[k]) { hist[idx * channels + ch] &+= 1 }
                        if let idx = map.index(u: -orbI[k], v: orbR[k]) { hist[idx * channels + ch] &+= 1 }
                    }
                }
            }
        }
    }

    // MARK: Strange attractors

    private static let cliffordSets: [(Double, Double, Double, Double)] = [
        (-1.4, 1.6, 1.0, 0.7), (-1.7, 1.3, -0.1, -1.21), (1.5, -1.8, 1.6, 0.9), (-1.8, -2.0, -0.5, -0.9),
    ]
    private static let deJongSets: [(Double, Double, Double, Double)] = [
        (1.641, 1.902, 0.316, 1.525), (-2.24, 0.43, -0.65, -2.43), (-2.7, -0.09, -0.86, -2.2), (0.97, -1.9, 1.38, -1.5),
    ]
    private static let henonSets: [(Double, Double)] = [(1.4, 0.3), (1.25, 0.3), (1.35, 0.25)]

    private static func attractor(_ kind: FractalKind, variant: Int) -> AccumSampler {
        switch kind {
        case .lorenz:
            return lorenz(view: variant)
        case .henon:
            let (a, b) = henonSets[variant % henonSets.count]
            return { map, seed, hist in
                var rng = SplitMix64(state: seed)
                var x = 0.1 * rng.nextDouble(), y = 0.1 * rng.nextDouble()
                for i in 0..<150_000 {
                    let nx = 1 - a * x * x + y
                    y = b * x
                    x = nx
                    if !x.isFinite || abs(x) > 1e6 { x = 0.1; y = 0.1 }
                    if i > 100, let idx = map.index(u: x, v: y) { hist[idx] &+= 1 }
                }
            }
        case .deJong:
            let (a, b, c, d) = deJongSets[variant % deJongSets.count]
            return { map, seed, hist in
                var rng = SplitMix64(state: seed)
                var x = rng.nextDouble() - 0.5, y = rng.nextDouble() - 0.5
                for i in 0..<200_000 {
                    let nx = sin(a * y) - cos(b * x)
                    let ny = sin(c * x) - cos(d * y)
                    x = nx; y = ny
                    if i > 100, let idx = map.index(u: x, v: y) { hist[idx] &+= 1 }
                }
            }
        default: // Clifford
            let (a, b, c, d) = cliffordSets[variant % cliffordSets.count]
            return { map, seed, hist in
                var rng = SplitMix64(state: seed)
                var x = rng.nextDouble() - 0.5, y = rng.nextDouble() - 0.5
                for i in 0..<200_000 {
                    let nx = sin(a * y) + c * cos(a * x)
                    let ny = sin(b * x) + d * cos(b * y)
                    x = nx; y = ny
                    if i > 100, let idx = map.index(u: x, v: y) { hist[idx] &+= 1 }
                }
            }
        }
    }

    private static func lorenz(view: Int) -> AccumSampler {
        { map, seed, hist in
            var rng = SplitMix64(state: seed)
            var x = 1 + rng.nextDouble(), y = 1 + rng.nextDouble(), z = 1 + rng.nextDouble()
            let sigma = 10.0, rho = 28.0, beta = 8.0 / 3.0, dt = 0.005
            func f(_ x: Double, _ y: Double, _ z: Double) -> (Double, Double, Double) {
                (sigma * (y - x), x * (rho - z) - y, x * y - beta * z)
            }
            for i in 0..<120_000 {
                let k1 = f(x, y, z)
                let k2 = f(x + 0.5 * dt * k1.0, y + 0.5 * dt * k1.1, z + 0.5 * dt * k1.2)
                let k3 = f(x + 0.5 * dt * k2.0, y + 0.5 * dt * k2.1, z + 0.5 * dt * k2.2)
                let k4 = f(x + dt * k3.0, y + dt * k3.1, z + dt * k3.2)
                x += dt / 6 * (k1.0 + 2 * k2.0 + 2 * k3.0 + k4.0)
                y += dt / 6 * (k1.1 + 2 * k2.1 + 2 * k3.1 + k4.1)
                z += dt / 6 * (k1.2 + 2 * k2.2 + 2 * k3.2 + k4.2)
                guard i > 500 else { continue }
                let u: Double, v: Double
                switch view % 3 {
                case 1: u = x; v = y
                case 2: u = y; v = z
                default: u = x; v = z
                }
                if let idx = map.index(u: u, v: v) { hist[idx] &+= 1 }
            }
        }
    }

    // MARK: Iterated function systems (chaos game)

    private static func ifs(_ kind: FractalKind) -> AccumSampler {
        switch kind {
        case .dragon:
            return { map, seed, hist in
                var rng = SplitMix64(state: seed)
                var x = 0.0, y = 0.0
                for i in 0..<250_000 {
                    if rng.next() & 1 == 0 {
                        (x, y) = ((x - y) / 2, (x + y) / 2)
                    } else {
                        (x, y) = (1 - (x + y) / 2, (x - y) / 2)
                    }
                    if i > 20, let idx = map.index(u: x, v: y) { hist[idx] &+= 1 }
                }
            }
        case .levy:
            return { map, seed, hist in
                var rng = SplitMix64(state: seed)
                var x = 0.0, y = 0.0
                for i in 0..<250_000 {
                    if rng.next() & 1 == 0 {
                        (x, y) = ((x + y) / 2, (y - x) / 2)
                    } else {
                        (x, y) = ((x - y) / 2 + 0.5, (x + y) / 2 - 0.5)
                    }
                    if i > 20, let idx = map.index(u: x, v: y) { hist[idx] &+= 1 }
                }
            }
        case .koch:
            return kochSnowflake()
        default: // Barnsley fern
            return { map, seed, hist in
                var rng = SplitMix64(state: seed)
                var x = 0.0, y = 0.0
                for i in 0..<250_000 {
                    let r = rng.nextDouble()
                    if r < 0.01 {
                        (x, y) = (0, 0.16 * y)
                    } else if r < 0.86 {
                        (x, y) = (0.85 * x + 0.04 * y, -0.04 * x + 0.85 * y + 1.6)
                    } else if r < 0.93 {
                        (x, y) = (0.2 * x - 0.26 * y, 0.23 * x + 0.22 * y + 1.6)
                    } else {
                        (x, y) = (-0.15 * x + 0.28 * y, 0.26 * x + 0.24 * y + 0.44)
                    }
                    if i > 20, let idx = map.index(u: x, v: y) { hist[idx] &+= 1 }
                }
            }
        }
    }

    /// Three Koch curves joined into a triangle.
    private static func kochSnowflake() -> AccumSampler {
        let s3 = 0.8660254037844386
        // Edges run clockwise so each curve's bump points outward.
        let edges: [(sx: Double, sy: Double, ex: Double, ey: Double)] = [
            (0, 0, 0.5, s3), (0.5, s3, 1, 0), (1, 0, 0, 0),
        ]
        return { map, seed, hist in
            var rng = SplitMix64(state: seed)
            var x = 0.0, y = 0.0
            for i in 0..<250_000 {
                switch rng.next() % 4 {
                case 0:
                    (x, y) = (x / 3, y / 3)
                case 1:
                    (x, y) = ((x * 0.5 - y * s3) / 3 + 1.0 / 3, (x * s3 + y * 0.5) / 3)
                case 2:
                    (x, y) = ((x * 0.5 + y * s3) / 3 + 0.5, (-x * s3 + y * 0.5) / 3 + s3 / 6)
                default:
                    (x, y) = (x / 3 + 2.0 / 3, y / 3)
                }
                guard i > 20 else { continue }
                let e = edges[Int(rng.next() % 3)]
                let dx = e.ex - e.sx, dy = e.ey - e.sy
                let u = e.sx + dx * x - dy * y
                let v = e.sy + dx * y + dy * x
                if let idx = map.index(u: u, v: v) { hist[idx] &+= 1 }
            }
        }
    }

    // MARK: Colorizing

    /// Log-scaled density through a palette: sparse areas are dark, crowded ones glow.
    private static func density(_ palette: FractalPalette) -> AccumColorizer {
        { hist, w, h in
            guard let top = hist.max(), top > 0 else { return nil }
            let lmax = log(1 + Double(top))
            var rgba = [UInt8](repeating: 255, count: w * h * 4)
            for i in 0..<(w * h) {
                let c = hist[i]
                if c == 0 { rgba[i * 4] = 0; rgba[i * 4 + 1] = 0; rgba[i * 4 + 2] = 0; continue }
                let v = log(1 + Double(c)) / lmax
                let col = palette.color(at: v * 0.92, brightness: pow(v, 0.5))
                rgba[i * 4] = col.0; rgba[i * 4 + 1] = col.1; rgba[i * 4 + 2] = col.2
            }
            return Raster.cgImage(width: w, height: h, rgba: rgba)
        }
    }

    /// Three independent density channels become red, green and blue.
    private static func rgb() -> AccumColorizer {
        { hist, w, h in
            var tops = [UInt32](repeating: 1, count: 3)
            for i in 0..<(w * h) {
                for ch in 0..<3 { tops[ch] = max(tops[ch], hist[i * 3 + ch]) }
            }
            let logs = tops.map { log(1 + Double($0)) }
            var rgba = [UInt8](repeating: 255, count: w * h * 4)
            for i in 0..<(w * h) {
                for ch in 0..<3 {
                    let v = log(1 + Double(hist[i * 3 + ch])) / logs[ch]
                    rgba[i * 4 + ch] = UInt8(min(1, pow(v, 1.3)) * 255)
                }
            }
            return Raster.cgImage(width: w, height: h, rgba: rgba)
        }
    }
}
