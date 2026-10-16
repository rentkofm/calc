import Foundation

/// Double pendulum with equal unit masses and unit rod lengths.
/// State is (θ1, θ2, ω1, ω2), angles measured from straight down.
struct PendulumState {
    var t1: Double
    var t2: Double
    var w1: Double = 0
    var w2: Double = 0
}

enum PendulumPhysics {
    static let gravity = 9.81

    @inline(__always)
    static func derivative(_ s: PendulumState) -> PendulumState {
        // Four trig calls; every other term is built from these.
        let s1 = sin(s.t1), c1 = cos(s.t1), s2 = sin(s.t2), c2 = cos(s.t2)
        let sd = s1 * c2 - c1 * s2                 // sin(θ1 − θ2)
        let cd = c1 * c2 + s1 * s2                 // cos(θ1 − θ2)
        let den = 4 - 2 * cd * cd                  // 3 − cos(2(θ1 − θ2))
        let sin1m2 = s1 * (c2 * c2 - s2 * s2) - c1 * (2 * s2 * c2)   // sin(θ1 − 2θ2)
        let w1s = s.w1 * s.w1, w2s = s.w2 * s.w2
        let a1 = (-gravity * (3 * s1 + sin1m2) - 2 * sd * (w2s + w1s * cd)) / den
        let a2 = (2 * sd * (2 * w1s + 2 * gravity * c1 + w2s * cd)) / den
        return PendulumState(t1: s.w1, t2: s.w2, w1: a1, w2: a2)
    }

    /// One classic RK4 step.
    @inline(__always)
    static func step(_ s: inout PendulumState, dt: Double) {
        func add(_ a: PendulumState, _ b: PendulumState, _ k: Double) -> PendulumState {
            PendulumState(t1: a.t1 + b.t1 * k, t2: a.t2 + b.t2 * k,
                          w1: a.w1 + b.w1 * k, w2: a.w2 + b.w2 * k)
        }
        let k1 = derivative(s)
        let k2 = derivative(add(s, k1, dt / 2))
        let k3 = derivative(add(s, k2, dt / 2))
        let k4 = derivative(add(s, k3, dt))
        s.t1 += dt / 6 * (k1.t1 + 2 * k2.t1 + 2 * k3.t1 + k4.t1)
        s.t2 += dt / 6 * (k1.t2 + 2 * k2.t2 + 2 * k3.t2 + k4.t2)
        s.w1 += dt / 6 * (k1.w1 + 2 * k2.w1 + 2 * k3.w1 + k4.w1)
        s.w2 += dt / 6 * (k1.w2 + 2 * k2.w2 + 2 * k3.w2 + k4.w2)
    }

    /// Wraps an angle into [-π, π). Starting angles are periodic, so the fractal tiles in both axes.
    @inline(__always)
    static func wrap(_ x: Double) -> Double { x - 2 * .pi * floor((x + .pi) / (2 * .pi)) }

    /// Largest step that keeps the integrator accurate for the current angular speeds.
    @inline(__always)
    static func maxStep(for s: PendulumState, limit: Double = 0.004) -> Double {
        min(limit, 0.04 / max(1, abs(s.w1), abs(s.w2)))
    }

    /// Released from rest, the pendulum can only reach θ₂ = π if 2cosθ₁ + cosθ₂ ≤ 1
    /// (energy conservation), and θ₁ can never reach π. So if this holds it never flips.
    @inline(__always)
    static func provablyStable(t1: Double, t2: Double) -> Bool { 2 * cos(t1) + cos(t2) > 1 }

    /// Time until either bob first flips over the top (|θ| > π), or nil if it never does within `limit`.
    static func flipTime(t1: Double, t2: Double, limit: Double, dt: Double = 0.02) -> Double? {
        if provablyStable(t1: t1, t2: t2) { return nil }
        var s = PendulumState(t1: t1, t2: t2)
        var t = 0.0
        while t < limit {
            step(&s, dt: dt)
            t += dt
            if abs(s.t1) > .pi || abs(s.t2) > .pi { return t }
        }
        return nil
    }
}
