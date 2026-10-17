import SwiftUI

/// Colours for the fractal, derived from the app's accent.
struct PendulumPalette {
    var lut: [(UInt8, UInt8, UInt8)]
    var stable: (UInt8, UInt8, UInt8)
    var hue: Double

    init(accent: Color, highlightStable: Bool) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(accent).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h)
        let hue = self.hue
        lut = (0..<256).map { i in
            let x = Double(i) / 255
            return Self.hsv(hue + 0.55 * x, 0.75, 1 - 0.35 * x)
        }
        stable = highlightStable ? Self.hsv(hue, 0.08, 1) : Self.hsv(hue, 0.6, 0.12)
    }

    func flipColor(_ t: Double, limit: Double) -> (UInt8, UInt8, UInt8) {
        let x = min(1, max(0, log(1 + t) / log(1 + limit)))
        return lut[Int(x * 255)]
    }

    /// Colour of a pendulum by its current angles: hue from θ₁, brightness from θ₂.
    func live(_ t1: Double, _ t2: Double) -> (UInt8, UInt8, UInt8) {
        Self.hsv(hue + PendulumPhysics.wrap(t1) / (2 * .pi), 0.8, 0.3 + 0.7 * (0.5 + 0.5 * cos(t2)))
    }

    static func hsv(_ hue: Double, _ sat: Double, _ val: Double) -> (UInt8, UInt8, UInt8) {
        let h = (hue - floor(hue)) * 6
        let i = Int(h) % 6, f = h - floor(h)
        let p = val * (1 - sat), q = val * (1 - sat * f), t = val * (1 - sat * (1 - f))
        let rgb: (Double, Double, Double)
        switch i {
        case 0: rgb = (val, t, p)
        case 1: rgb = (q, val, p)
        case 2: rgb = (p, val, t)
        case 3: rgb = (p, q, val)
        case 4: rgb = (t, p, val)
        default: rgb = (val, p, q)
        }
        return (UInt8(max(0, min(255, rgb.0 * 255))), UInt8(max(0, min(255, rgb.1 * 255))), UInt8(max(0, min(255, rgb.2 * 255))))
    }
}

/// A grid of pendulums, one per pixel, all released from rest at their pixel's starting angles
/// and advanced together as time passes. Angles are periodic, so the starting angles wrap and the
/// picture tiles forever in both directions.
@Observable
final class PendulumField {
    enum Style { case grow, live }

    private(set) var image: CGImage?
    /// The region `image` was rendered for (the field itself may have been re-seeded since).
    private(set) var imageViewport = Viewport()
    private(set) var time = 0.0

    @ObservationIgnored private var viewport = Viewport()
    @ObservationIgnored private var w = 0
    @ObservationIgnored private var h = 0
    @ObservationIgnored private var states: [PendulumState] = []
    @ObservationIgnored private var flip: [Float] = []
    @ObservationIgnored private var skip: [Bool] = []
    @ObservationIgnored var lastTick: Date?
    private var stepSize = 0.01

    /// Starts every pixel's pendulum from rest. With `skipStable`, pixels that provably never flip aren't simulated.
    /// With `momentum` (fixed starting angles), the plane is instead (p₁, p₂): each pixel starts at those angles
    /// with the velocities its canonical momenta imply, the plane isn't periodic, and nothing is skipped.
    func reset(viewport vp: Viewport, cell: CGFloat, skipStable: Bool, momentum: (t1: Double, t2: Double)? = nil) {
        stepSize = momentum == nil ? 0.01 : 0.004
        viewport = vp
        w = max(1, Int(vp.size.width / cell))
        h = max(1, Int(vp.size.height / cell))
        let kx = Double(vp.size.width) / Double(w), ky = Double(vp.size.height) / Double(h)
        let cx = vp.center.doubleX, cy = vp.center.doubleY, s = vp.scale
        let hw = Double(vp.size.width) / 2, hh = Double(vp.size.height) / 2
        states = [PendulumState](repeating: PendulumState(t1: 0, t2: 0), count: w * h)
        flip = [Float](repeating: -1, count: w * h)
        skip = [Bool](repeating: false, count: w * h)
        for j in 0..<h {
            let y = cy - ((Double(j) + 0.5) * ky - hh) / s
            for i in 0..<w {
                let x = cx + ((Double(i) + 0.5) * kx - hw) / s
                if let m = momentum {
                    let v = PendulumPhysics.velocities(t1: m.t1, t2: m.t2, p1: x, p2: y)
                    states[j * w + i] = PendulumState(t1: m.t1, t2: m.t2, w1: v.w1, w2: v.w2)
                } else {
                    let t1 = PendulumPhysics.wrap(x), t2 = PendulumPhysics.wrap(y)
                    states[j * w + i] = PendulumState(t1: t1, t2: t2)
                    if skipStable && PendulumPhysics.provablyStable(t1: t1, t2: t2) { skip[j * w + i] = true }
                }
            }
        }
        time = 0
        lastTick = nil
    }

    func advance(by dt: Double) {
        let n = w * h
        guard n > 0, dt > 0 else { return }
        let steps = max(1, Int((dt / stepSize).rounded(.up)))
        let hs = dt / Double(steps)
        let t0 = time
        let chunk = 256
        let chunks = (n + chunk - 1) / chunk
        states.withUnsafeMutableBufferPointer { sb in
            flip.withUnsafeMutableBufferPointer { fb in
                skip.withUnsafeBufferPointer { kb in
                    let S = sb.baseAddress!, F = fb.baseAddress!, K = kb.baseAddress!
                    DispatchQueue.concurrentPerform(iterations: chunks) { c in
                        for i in (c * chunk)..<min(n, (c + 1) * chunk) where !K[i] {
                            var st = S[i]
                            var f = F[i]
                            for k in 0..<steps {
                                PendulumPhysics.step(&st, dt: hs)
                                if f < 0 && (abs(st.t1) > .pi || abs(st.t2) > .pi) { f = Float(t0 + Double(k + 1) * hs) }
                            }
                            S[i] = st
                            F[i] = f
                        }
                    }
                }
            }
        }
        time += dt
    }

    func updateImage(style: Style, palette: PendulumPalette, limit: Double) {
        let w = self.w, h = self.h, n = w * h
        guard n > 0 else { return }
        let now = time
        var rgba = [UInt8](repeating: 255, count: n * 4)
        rgba.withUnsafeMutableBufferPointer { out in
            states.withUnsafeBufferPointer { sb in
                flip.withUnsafeBufferPointer { fb in
                    let O = out.baseAddress!, S = sb.baseAddress!, F = fb.baseAddress!
                    DispatchQueue.concurrentPerform(iterations: h) { j in
                        for i in 0..<w {
                            let k = j * w + i
                            let c: (UInt8, UInt8, UInt8)
                            switch style {
                            case .grow:
                                let f = Double(F[k])
                                c = (f >= 0 && f <= now) ? palette.flipColor(f, limit: limit) : palette.stable
                            case .live:
                                c = palette.live(S[k].t1, S[k].t2)
                            }
                            O[k * 4] = c.0; O[k * 4 + 1] = c.1; O[k * 4 + 2] = c.2
                        }
                    }
                }
            }
        }
        image = Raster.cgImage(width: w, height: h, rgba: rgba)
        imageViewport = viewport
    }
}
