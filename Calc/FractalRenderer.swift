import SwiftUI

typealias PixelRGB = (UInt8, UInt8, UInt8)

enum FractalRenderer {
    private static let black: PixelRGB = (0, 0, 0)
    private static let lyapunovSequences = ["AB", "AABAB", "BBBBBBAAAAAA", "ABBBAAB"]

    static func render(_ p: FractalParams, size: CGSize, cell: CGFloat) -> CGImage? {
        if p.kind.supportsDeepZoom && p.scale > 1e9 { return renderDeep(p, size: size, cell: cell) }
        let cx = p.center.doubleX, cy = p.center.doubleY, s = Double(p.scale)
        let hw = Double(size.width) / 2, hh = Double(size.height) / 2
        let cosR = cos(p.rotation), sinR = sin(p.rotation)
        return Raster.image(size: size, cell: cell) { sx, sy in
            let ox = sx - hw, oy = -(sy - hh)
            let x = cx + (ox * cosR - oy * sinR) / s, y = cy + (ox * sinR + oy * cosR) / s
            switch p.kind {
            case .newton, .newton4, .newton5, .newtonChaos, .halley:
                return newtonBasin(p, x: x, y: y)
            case .lyapunov:
                return lyapunov(p, x: x, y: y)
            default:
                let e = escape(p, x: x, y: y)
                guard e.mu >= 0 else { return black }
                return colorize(p, e, scale: s)
            }
        }
    }

    static func colorize(_ p: FractalParams, _ e: (mu: Double, aux: Double), scale s: Double) -> PixelRGB {
        let f = p.kind.colorFrequency
        guard p.kind.supportsColoring else { return p.palette.color(forMu: e.mu, frequency: f) }
        switch p.coloring {
        case .smooth:
            return p.palette.color(forMu: e.mu, frequency: f)
        case .distance:
            guard p.kind.supportsDistance else { return p.palette.color(forMu: e.mu, frequency: f) }
            // Distance to the set in pixels: filaments fade to black as they thin out.
            let v = min(1, max(0, e.aux * s * 0.35))
            return p.palette.color(forMu: e.mu, frequency: f, brightness: pow(v, 0.35))
        case .orbitTrap:
            // Closest approach to the axes: gives the "stalk" pattern.
            return p.palette.color(at: -log(max(e.aux, 1e-6)) * 0.2)
        case .triangle:
            return p.palette.color(at: e.aux * 0.9)
        case .curvature:
            return p.palette.color(at: e.aux * 0.5)
        }
    }

    // MARK: Escape time

    /// Smooth escape time (or -1 when the point never escapes) plus a value for the chosen coloring mode.
    static func escape(_ p: FractalParams, x: Double, y: Double) -> (mu: Double, aux: Double) {
        switch p.kind {
        case .carpet, .cantorDust, .vicsek: return (ternary(p.kind, x, y, p.maxIter), 0)
        case .sierpinski: return (sierpinski(x, y, p.maxIter), 0)
        case .magnet: return (magnet(x, y, p.maxIter), 0)
        case .magnet2: return (magnet2(x, y, p.maxIter), 0)
        case .nova: return (nova(x, y, p.maxIter), 0)
        case .sine, .cosine, .exponential: return (transcendental(p.kind, x, y, p.maxIter), 0)
        case .collatz: return (collatz(x, y, p.maxIter), 0)
        case .gamma: return (gammaIteration(x, y, min(p.maxIter, 200)), 0)
        default: break
        }

        var zr = 0.0, zi = 0.0, cr = x, ci = y
        var pzr = 0.0, pzi = 0.0 // previous z, for Phoenix
        switch p.kind {
        case .julia, .burningJulia:
            zr = x; zi = y; cr = p.juliaC.re; ci = p.juliaC.im
        case .phoenix:
            zr = x; zi = y; cr = 0.5667; ci = 0
        case .lambda:
            zr = 0.5
        case .custom:
            // Blend from Mandelbrot (z₀ = 0, c = pixel) to Julia (z₀ = pixel, c fixed).
            let t = p.morph
            zr = t * x; zi = t * y
            cr = (1 - t) * x + t * p.juliaC.re
            ci = (1 - t) * y + t * p.juliaC.im
        case .inverse:
            let d = x * x + y * y
            if d == 0 { return (-1, 0) }
            cr = x / d; ci = -y / d
        case .mandelbrot:
            // Skip the main cardioid and period-2 bulb.
            let q = (x - 0.25) * (x - 0.25) + y * y
            if q * (q + (x - 0.25)) < 0.25 * y * y || (x + 1) * (x + 1) + y * y < 0.0625 { return (-1, 0) }
        default:
            break
        }

        let mode = p.kind.supportsColoring ? p.coloring : .smooth
        let wantDE = mode == .distance && p.kind.supportsDistance
        var dzr = p.kind == .julia ? 1.0 : 0.0, dzi = 0.0
        let cmag = hypot(cr, ci)
        var trap = Double.infinity
        var triSum = 0.0, triN = 0.0
        var curvSum = 0.0, curvN = 0.0
        var q1r = zr, q1i = zi // z(n-1), for curvature

        var i = 0
        var m = 0.0
        while i < p.maxIter {
            let r2 = zr * zr, i2 = zi * zi
            m = r2 + i2
            if m > 256 { break }
            let oldr = zr, oldi = zi

            if wantDE {
                let ndr = 2 * (oldr * dzr - oldi * dzi) + (p.kind == .mandelbrot ? 1 : 0)
                let ndi = 2 * (oldr * dzi + oldi * dzr)
                dzr = ndr; dzi = ndi
            }

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
            case .quintic:
                let ar = r2 - i2, ai = 2 * zr * zi // z²
                let br = ar * ar - ai * ai, bi = 2 * ar * ai // z⁴
                let nr = br * zr - bi * zi + cr
                zi = br * zi + bi * zr + ci
                zr = nr
            case .celtic:
                let nr = abs(r2 - i2) + cr
                zi = 2 * zr * zi + ci
                zr = nr
            case .perpendicular:
                zi = -2 * abs(zr) * zi + ci
                zr = r2 - i2 + cr
            case .phoenix:
                let nr = r2 - i2 + cr - 0.5 * pzr
                let ni = 2 * zr * zi - 0.5 * pzi
                pzr = zr; pzi = zi
                zr = nr; zi = ni
            case .lambda:
                // z ← c·z·(1 − z)
                let wr = zr - r2 + i2, wi = zi - 2 * zr * zi
                zr = cr * wr - ci * wi
                zi = cr * wi + ci * wr
            case .custom:
                let k = p.coef
                if p.power == 2 {
                    zi = k * (2 * zr * zi) + ci
                    zr = k * (r2 - i2) + cr
                } else {
                    let r = m.squareRoot()
                    if r == 0 {
                        zr = cr; zi = ci
                    } else {
                        let a = atan2(zi, zr) * p.power
                        let rp = k * pow(r, p.power)
                        zr = rp * cos(a) + cr
                        zi = rp * sin(a) + ci
                    }
                }
            case .fracPower:
                let r = m.squareRoot()
                if r == 0 {
                    zr = cr; zi = ci
                } else {
                    let a = atan2(zi, zr) * p.power
                    let rp = pow(r, p.power)
                    zr = rp * cos(a) + cr
                    zi = rp * sin(a) + ci
                }
            default:
                break
            }
            i += 1

            switch mode {
            case .smooth, .distance:
                break
            case .orbitTrap:
                trap = min(trap, min(abs(zr), abs(zi)))
            case .triangle:
                let mn = (zr * zr + zi * zi).squareRoot()
                let lo = abs(m - cmag), hi = m + cmag
                if hi - lo > 1e-12 { triSum += (mn - lo) / (hi - lo); triN += 1 }
            case .curvature:
                let ur = zr - oldr, ui = zi - oldi
                let vr = oldr - q1r, vi = oldi - q1i
                if i > 1 { curvSum += abs(atan2(ui * vr - ur * vi, ur * vr + ui * vi)); curvN += 1 }
                q1r = oldr; q1i = oldi
            }
        }
        if i >= p.maxIter { return (-1, 0) }

        let degree = (p.kind == .fracPower || p.kind == .custom) ? p.power : p.kind.degree
        let mu = Double(i) + 1 - log2(0.5 * log(m)) / log2(degree)
        let aux: Double
        switch mode {
        case .distance:
            let mz = m.squareRoot(), dz = hypot(dzr, dzi)
            aux = dz > 0 ? 0.5 * mz * log(mz) / dz : 0
        case .orbitTrap: aux = trap
        case .triangle: aux = triN > 0 ? max(0, min(1, triSum / triN)) : 0
        case .curvature: aux = curvN > 0 ? curvSum / curvN : 0
        case .smooth: aux = 0
        }
        return (mu, aux)
    }

    // MARK: Special escape-time maps

    /// Base-3 self-similar sets (carpet, Cantor dust, Vicsek). Removed cells are colored by the level they appear at.
    private static func ternary(_ kind: FractalKind, _ x0: Double, _ y0: Double, _ maxIter: Int) -> Double {
        guard x0 >= 0, x0 < 1, y0 >= 0, y0 < 1 else { return -1 }
        var x = x0, y = y0
        for level in 0..<30 { // ×3 isn't exact in binary; deeper levels are noise
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

    /// Sierpinski triangle (gasket): the removed triangles are colored by level.
    private static func sierpinski(_ x0: Double, _ y0: Double, _ maxIter: Int) -> Double {
        guard x0 >= 0, x0 < 1, y0 >= 0, y0 < 1 else { return -1 }
        var x = x0, y = y0
        for level in 0..<50 { // ×2 is exact in binary
            x *= 2; y *= 2
            let ix = floor(x), iy = floor(y)
            if ix == 1 && iy == 1 { return Double(level) }
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

    /// Magnet fractal (type II): z ← ((z³ + 3(c−1)z + (c−1)(c−2)) / (3z² + 3(c−2)z + (c−1)(c−2) + 1))².
    private static func magnet2(_ x: Double, _ y: Double, _ maxIter: Int) -> Double {
        let c = Complex(x, y)
        let c1 = c - Complex(1), c2 = c - Complex(2)
        let c12 = c1 * c2
        let three = Complex(3), one = Complex(1)
        var z = Complex(0)
        for i in 0..<maxIter {
            let num = z * z * z + three * c1 * z + c12
            let den = three * z * z + three * c2 * z + c12 + one
            let q = num / den
            z = q * q
            let m = z.re * z.re + z.im * z.im
            if m > 256 { return Double(i) + 1 - log2(0.5 * log(m)) }
            let dx = z.re - 1
            if dx * dx + z.im * z.im < 1e-8 { return -1 }
        }
        return -1
    }

    /// Nova: Newton's method on z³ − 1 with a constant added each step; colored by how fast it settles.
    private static func nova(_ x: Double, _ y: Double, _ maxIter: Int) -> Double {
        let c = Complex(x, y)
        let three = Complex(3), one = Complex(1)
        var z = Complex(1)
        for i in 0..<maxIter {
            let z2 = z * z
            let d = three * z2
            if d.re == 0 && d.im == 0 { return -1 }
            let nz = z - (z2 * z - one) / d + c
            let dx = nz.re - z.re, dy = nz.im - z.im
            z = nz
            if !z.re.isFinite || !z.im.isFinite || z.re * z.re + z.im * z.im > 1e12 { return -1 }
            if dx * dx + dy * dy < 1e-14 { return Double(i) }
        }
        return -1
    }

    /// z ← c·sin z, c·cos z or c·eˢ — escape time with exploding imaginary (or real) part.
    private static func transcendental(_ kind: FractalKind, _ x: Double, _ y: Double, _ maxIter: Int) -> Double {
        let c = Complex(x, y)
        var z = kind == .sine ? Complex(Double.pi / 2) : Complex(0)
        for i in 0..<maxIter {
            switch kind {
            case .sine: z = c * CMath.csin(z)
            case .cosine: z = c * CMath.ccos(z)
            default: z = c * CMath.cexp(z)
            }
            if !z.re.isFinite || !z.im.isFinite { return Double(i) }
            let escaped = kind == .exponential ? (z.re > 50) : (abs(z.im) > 50)
            if escaped { return Double(i) + 1 }
        }
        return -1
    }

    /// The complex extension of the Collatz map: z ← (7z + 2 − (5z + 2)·cos(πz)) / 4.
    private static func collatz(_ x: Double, _ y: Double, _ maxIter: Int) -> Double {
        var z = Complex(x, y)
        let pi = Complex(Double.pi), two = Complex(2), four = Complex(4)
        for i in 0..<maxIter {
            let cs = CMath.ccos(pi * z)
            z = (Complex(7) * z + two - (Complex(5) * z + two) * cs) / four
            if !z.re.isFinite || !z.im.isFinite || abs(z.im) > 20 || z.re * z.re + z.im * z.im > 1e8 {
                return Double(i)
            }
        }
        return -1
    }

    /// Iterating the Gamma function; points that blow up near its poles are colored.
    private static func gammaIteration(_ x: Double, _ y: Double, _ maxIter: Int) -> Double {
        var z = Complex(x, y)
        for i in 0..<maxIter {
            z = CMath.cgamma(z)
            if !z.re.isFinite || !z.im.isFinite || z.re * z.re + z.im * z.im > 1e6 { return Double(i) }
        }
        return -1
    }

    // MARK: Newton basins

    static func newtonRoots(_ kind: FractalKind) -> [Complex] {
        switch kind {
        case .newtonChaos:
            return [Complex(-1.7692923542386314), Complex(0.8846461771193157, 0.5897428050222055),
                    Complex(0.8846461771193157, -0.5897428050222055)]
        case .newton4, .newton5:
            let n = kind == .newton4 ? 4 : 5
            return (0..<n).map { Complex(cos(2 * Double.pi * Double($0) / Double(n)), sin(2 * Double.pi * Double($0) / Double(n))) }
        default:
            let s3 = 0.8660254037844386
            return [Complex(1), Complex(-0.5, s3), Complex(-0.5, -s3)]
        }
    }

    private static func newtonStep(_ kind: FractalKind, _ z: Complex) -> Complex {
        let one = Complex(1)
        switch kind {
        case .newtonChaos: // z³ − 2z + 2: has a famous attracting cycle 0 → 1 → 0
            let z2 = z * z
            return z - (z2 * z - Complex(2) * z + Complex(2)) / (Complex(3) * z2 - Complex(2))
        case .halley: // Halley's method on z³ − 1
            let z2 = z * z
            let f = z2 * z - one, df = Complex(3) * z2, ddf = Complex(6) * z
            return z - Complex(2) * f * df / (Complex(2) * df * df - f * ddf)
        default: // z^n − 1
            let n = kind == .newton4 ? 4 : kind == .newton5 ? 5 : 3
            var zn1 = one
            for _ in 0..<(n - 1) { zn1 = zn1 * z }
            return z - (zn1 * z - one) / (Complex(Double(n)) * zn1)
        }
    }

    /// Colors each point by the root Newton's method converges to, darker the longer it takes.
    private static func newtonBasin(_ p: FractalParams, x: Double, y: Double) -> PixelRGB {
        let roots = newtonRoots(p.kind)
        var z = Complex(x, y)
        for i in 0..<min(p.maxIter, 200) {
            z = newtonStep(p.kind, z)
            for (k, r) in roots.enumerated() {
                let dx = z.re - r.re, dy = z.im - r.im
                if dx * dx + dy * dy < 1e-10 {
                    let brightness = max(0.2, 1 - Double(i) / 30)
                    return p.palette.color(at: Double(k) / Double(roots.count) * 0.9 + 0.1, brightness: brightness)
                }
            }
        }
        return black
    }

    // MARK: Lyapunov

    /// Lyapunov exponent of the logistic map driven by a sequence of two parameters (x = A, y = B).
    private static func lyapunov(_ p: FractalParams, x a: Double, y b: Double) -> PixelRGB {
        let seq = Array(lyapunovSequences[p.variant % lyapunovSequences.count])
        var xn = 0.5
        var sum = 0.0
        let warmup = 40, steps = max(40, p.maxIter)
        for i in 0..<(warmup + steps) {
            let r = seq[i % seq.count] == "A" ? a : b
            if i >= warmup { sum += log(max(abs(r * (1 - 2 * xn)), 1e-300)) }
            xn = r * xn * (1 - xn)
        }
        let lambda = sum / Double(steps)
        guard lambda.isFinite, lambda < 0 else { return black }
        return p.palette.color(at: min(1, -lambda * 0.8) * 0.9 + 0.05)
    }
}

// MARK: - Complex Gamma

extension CMath {
    private static let lanczos: [Double] = [
        0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
        -176.61502916214059, 12.507343278686905, -0.13857109526572012,
        9.9843695780195716e-6, 1.5056327351493116e-7,
    ]

    /// Γ(z) by the Lanczos approximation, with the reflection formula for Re z < ½.
    static func cgamma(_ z: Complex) -> Complex {
        let pi = Complex(Double.pi)
        if z.re < 0.5 {
            return pi / (csin(pi * z) * cgamma(Complex(1) - z))
        }
        let zz = z - Complex(1)
        var x = Complex(lanczos[0])
        for i in 1..<lanczos.count {
            x = x + Complex(lanczos[i]) / (zz + Complex(Double(i)))
        }
        let t = zz + Complex(7.5)
        return Complex((2 * Double.pi).squareRoot()) * cpow(t, zz + Complex(0.5)) * cexp(-t) * x
    }
}
