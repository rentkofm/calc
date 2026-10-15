import SwiftUI

struct Ray3DParams {
    var kind: FractalKind
    var palette: FractalPalette
    var yaw: Double
    var pitch: Double
    var dist: Double
    var target: SIMD3<Double>
    var power: Double       // Mandelbulb power / Mandelbox scale
    var iterations: Int
    var roll: Double = 0
}

/// CPU ray-marcher for the Mandelbulb and Mandelbox, using distance estimators.
enum Fractal3D {
    typealias V3 = SIMD3<Double>

    static let fov = 0.55 // tan of half the vertical field of view

    struct Camera {
        var pos: V3, fwd: V3, right: V3, up: V3
    }

    private static func dot(_ a: V3, _ b: V3) -> Double { (a * b).sum() }
    private static func length(_ a: V3) -> Double { dot(a, a).squareRoot() }
    private static func normalize(_ a: V3) -> V3 {
        let l = length(a)
        return l > 0 ? a / l : a
    }
    private static func cross(_ a: V3, _ b: V3) -> V3 {
        V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    static func camera(_ p: Ray3DParams) -> Camera {
        let dir = V3(cos(p.pitch) * sin(p.yaw), sin(p.pitch), cos(p.pitch) * cos(p.yaw))
        let fwd = -dir
        let right = normalize(cross(fwd, V3(0, 1, 0)))
        let up = cross(right, fwd)
        let cr = cos(p.roll), sr = sin(p.roll)
        return Camera(pos: p.target + dir * p.dist, fwd: fwd, right: right * cr + up * sr, up: up * cr - right * sr)
    }

    static func cameraPosition(_ p: Ray3DParams) -> V3 { camera(p).pos }

    // MARK: Distance estimators

    private static func estimate(_ p: Ray3DParams, _ q: V3) -> (d: Double, trap: Double) {
        p.kind == .mandelbox ? boxDE(q, scale: p.power, iters: p.iterations)
                             : bulbDE(q, power: p.power, iters: p.iterations)
    }

    private static func bulbDE(_ p: V3, power: Double, iters: Int) -> (d: Double, trap: Double) {
        var z = p
        var dr = 1.0, r = 0.0, trap = 1e10
        for _ in 0..<iters {
            r = length(z)
            if r > 2 { break }
            trap = min(trap, r)
            let theta = acos(max(-1, min(1, z.z / max(r, 1e-300))))
            let phi = atan2(z.y, z.x)
            let rp = pow(r, power - 1)
            dr = rp * power * dr + 1
            let nt = theta * power, np = phi * power
            z = V3(sin(nt) * cos(np), sin(nt) * sin(np), cos(nt)) * (rp * r) + p
        }
        return (0.5 * log(max(r, 1e-300)) * r / dr, trap)
    }

    private static func boxDE(_ p: V3, scale: Double, iters: Int) -> (d: Double, trap: Double) {
        func fold(_ v: Double) -> Double { v > 1 ? 2 - v : (v < -1 ? -2 - v : v) }
        var z = p
        var dr = 1.0, trap = 1e10
        for _ in 0..<iters {
            z = V3(fold(z.x), fold(z.y), fold(z.z))
            let r2 = dot(z, z)
            if r2 < 0.25 { z *= 4; dr *= 4 } else if r2 < 1 { z /= r2; dr /= r2 }
            trap = min(trap, r2.squareRoot())
            z = z * scale + p
            dr = dr * abs(scale) + 1
        }
        return (length(z) / abs(dr), trap)
    }

    // MARK: Ray marching

    private static func bound(_ p: Ray3DParams) -> Double {
        p.kind == .mandelbox ? max(6, abs(p.power) * 4 + 2) : 2.2
    }

    private static func march(_ p: Ray3DParams, origin o: V3, dir: V3, pixelAngle: Double,
                              maxSteps: Int) -> (t: Double, steps: Int, trap: Double, hit: Bool) {
        let b = bound(p)
        let ol = length(o)
        var t = max(0, ol - b)
        let tmax = ol + b
        var trap = 0.0
        var steps = 0
        while steps < maxSteps {
            let est = estimate(p, o + dir * t)
            trap = est.trap
            if est.d < max(pixelAngle * t * 0.5, 1e-13) { return (t, steps, trap, true) }
            t += est.d * 0.9
            if t > tmax { return (t, steps, trap, false) }
            steps += 1
        }
        return (t, steps, trap, true) // out of steps next to the surface: treat as a grazing hit
    }

    private static func rayDirection(_ cam: Camera, sx: Double, sy: Double, size: CGSize) -> (dir: V3, pixelAngle: Double) {
        let hw = Double(size.width) / 2, hh = Double(size.height) / 2
        let uvx = (sx - hw) / hh * fov, uvy = -(sy - hh) / hh * fov
        return (normalize(cam.fwd + cam.right * uvx + cam.up * uvy), fov / hh)
    }

    private static func shade(_ p: Ray3DParams, cam: Camera, sx: Double, sy: Double,
                              size: CGSize, maxSteps: Int) -> PixelRGB {
        let (dir, pixelAngle) = rayDirection(cam, sx: sx, sy: sy, size: size)
        let r = march(p, origin: cam.pos, dir: dir, pixelAngle: pixelAngle, maxSteps: maxSteps)
        if !r.hit {
            let g = 0.12 * (1 - sy / Double(size.height))
            return (UInt8(g * 0.5 * 255), UInt8(g * 0.7 * 255), UInt8(g * 255))
        }

        let pos = cam.pos + dir * r.t
        let h = max(pixelAngle * r.t, 1e-13)
        let k0 = V3(1, -1, -1), k1 = V3(-1, -1, 1), k2 = V3(-1, 1, -1), k3 = V3(1, 1, 1)
        let n = normalize(k0 * estimate(p, pos + k0 * h).d + k1 * estimate(p, pos + k1 * h).d
                          + k2 * estimate(p, pos + k2 * h).d + k3 * estimate(p, pos + k3 * h).d)

        let light = normalize(cam.right * 0.5 + cam.up * 0.8 - cam.fwd * 0.7)
        let diffuse = max(0, dot(n, light))
        let specular = pow(max(0, dot(n, normalize(light - dir))), 24) * 0.35
        let occlusion = 1 - min(1, Double(r.steps) / Double(maxSteps))
        let lit = (0.18 + 0.82 * diffuse) * (0.35 + 0.65 * occlusion)

        let base = p.palette.color(at: r.trap * 0.5 + 0.1)
        func channel(_ c: UInt8) -> UInt8 { UInt8(min(1, Double(c) / 255 * lit + specular) * 255) }
        return (channel(base.0), channel(base.1), channel(base.2))
    }

    static func render(_ p: Ray3DParams, size: CGSize, cell: CGFloat) -> CGImage? {
        let cam = camera(p)
        let maxSteps = cell >= 2 ? 70 : 160
        return Raster.image(size: size, cell: cell) { sx, sy in
            shade(p, cam: cam, sx: sx, sy: sy, size: size, maxSteps: maxSteps)
        }
    }

    /// The surface point under a screen position, if the ray hits.
    static func cast(_ p: Ray3DParams, size: CGSize, at point: CGPoint) -> V3? {
        let cam = camera(p)
        let (dir, pixelAngle) = rayDirection(cam, sx: Double(point.x), sy: Double(point.y), size: size)
        let r = march(p, origin: cam.pos, dir: dir, pixelAngle: pixelAngle, maxSteps: 400)
        return r.hit ? cam.pos + dir * r.t : nil
    }
}
