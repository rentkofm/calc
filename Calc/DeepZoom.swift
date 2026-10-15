import SwiftUI

// MARK: - Arbitrary-precision fixed point

/// Sign-magnitude fixed-point number with 32-bit limbs (little-endian).
/// The top limb is the integer part, the rest are fractional, so |value| < 2³² and the
/// resolution is 2^(-32·fracLimbs). Plenty for coordinates near the Mandelbrot set.
struct BigFixed: Equatable {
    var negative = false
    var mag: [UInt32]

    var fracLimbs: Int { mag.count - 1 }

    init(fracLimbs f: Int) {
        mag = [UInt32](repeating: 0, count: f + 1)
    }

    init(_ d: Double, fracLimbs f: Int) {
        self.init(fracLimbs: f)
        guard d.isFinite, d != 0 else { return }
        let a = abs(d)
        let m: UInt64
        let e2: Int
        if a.isNormal {
            m = (1 << 52) | a.significandBitPattern
            e2 = Int(a.exponent) - 52
        } else {
            m = a.significandBitPattern
            e2 = -1074
        }
        let shift = e2 + 32 * f // bit position of m's lowest bit within the limb array
        if shift >= 0 {
            let k = shift / 32, b = UInt64(shift % 32)
            addUInt64((m & 0xFFFF_FFFF) << b, at: k)
            addUInt64((m >> 32) << b, at: k + 1)
        } else if -shift < 64 {
            addUInt64(m >> UInt64(-shift), at: 0)
        }
        negative = d < 0 && mag.contains { $0 != 0 }
    }

    private mutating func addUInt64(_ v: UInt64, at k: Int) {
        var carry = v
        var i = k
        while carry != 0, i < mag.count {
            let t = UInt64(mag[i]) + (carry & 0xFFFF_FFFF)
            mag[i] = UInt32(truncatingIfNeeded: t)
            carry = (carry >> 32) + (t >> 32)
            i += 1
        }
    }

    var doubleValue: Double {
        var top = mag.count - 1
        while top >= 0 && mag[top] == 0 { top -= 1 }
        guard top >= 0 else { return 0 }
        var r = 0.0
        for k in stride(from: top, through: max(0, top - 2), by: -1) {
            r += Double(sign: .plus, exponent: 32 * (k - fracLimbs), significand: Double(mag[k]))
        }
        return negative ? -r : r
    }

    private static func compare(_ a: [UInt32], _ b: [UInt32]) -> Int {
        for k in stride(from: a.count - 1, through: 0, by: -1) where a[k] != b[k] {
            return a[k] > b[k] ? 1 : -1
        }
        return 0
    }

    private static func add(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
        var r = a
        var carry: UInt64 = 0
        for k in 0..<a.count {
            let t = UInt64(a[k]) + UInt64(b[k]) + carry
            r[k] = UInt32(truncatingIfNeeded: t)
            carry = t >> 32
        }
        return r
    }

    /// a − b, where a ≥ b.
    private static func sub(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
        var r = a
        var borrow: Int64 = 0
        for k in 0..<a.count {
            var t = Int64(a[k]) - Int64(b[k]) - borrow
            if t < 0 { t += 1 << 32; borrow = 1 } else { borrow = 0 }
            r[k] = UInt32(truncatingIfNeeded: t)
        }
        return r
    }

    func adding(_ o: BigFixed) -> BigFixed {
        var r = BigFixed(fracLimbs: fracLimbs)
        if negative == o.negative {
            r.mag = Self.add(mag, o.mag)
            r.negative = negative
        } else {
            let c = Self.compare(mag, o.mag)
            if c == 0 { return r }
            if c > 0 { r.mag = Self.sub(mag, o.mag); r.negative = negative }
            else { r.mag = Self.sub(o.mag, mag); r.negative = o.negative }
        }
        if !r.mag.contains(where: { $0 != 0 }) { r.negative = false }
        return r
    }

    func negated() -> BigFixed {
        var r = self
        if r.mag.contains(where: { $0 != 0 }) { r.negative.toggle() }
        return r
    }

    func subtracting(_ o: BigFixed) -> BigFixed { adding(o.negated()) }

    func multiplied(by o: BigFixed) -> BigFixed {
        let n = mag.count
        var prod = [UInt32](repeating: 0, count: 2 * n)
        for i in 0..<n {
            let ai = UInt64(mag[i])
            if ai == 0 { continue }
            var carry: UInt64 = 0
            for j in 0..<n {
                let t = ai * UInt64(o.mag[j]) + UInt64(prod[i + j]) + carry
                prod[i + j] = UInt32(truncatingIfNeeded: t)
                carry = t >> 32
            }
            prod[i + n] = UInt32(truncatingIfNeeded: carry)
        }
        var r = BigFixed(fracLimbs: fracLimbs)
        let f = fracLimbs
        for k in 0..<n { r.mag[k] = prod[f + k] }
        r.negative = (negative != o.negative) && r.mag.contains { $0 != 0 }
        return r
    }

    func converted(fracLimbs newF: Int) -> BigFixed {
        var r = BigFixed(fracLimbs: newF)
        r.negative = negative
        let shift = newF - fracLimbs
        for k in 0..<mag.count {
            let nk = k + shift
            if nk >= 0 && nk < r.mag.count { r.mag[nk] = mag[k] }
        }
        return r
    }
}

/// A point on the plane stored with enough precision to zoom to roughly 1e300.
struct Center: Equatable {
    static let fracLimbs = 40 // 1280 fractional bits

    var x: BigFixed
    var y: BigFixed

    init(x: Double, y: Double) {
        self.x = BigFixed(x, fracLimbs: Self.fracLimbs)
        self.y = BigFixed(y, fracLimbs: Self.fracLimbs)
    }

    init(big x: BigFixed, _ y: BigFixed) {
        self.x = x
        self.y = y
    }

    var doubleX: Double { x.doubleValue }
    var doubleY: Double { y.doubleValue }

    func moved(dx: Double, dy: Double) -> Center {
        Center(big: x.adding(BigFixed(dx, fracLimbs: Self.fracLimbs)),
               y.adding(BigFixed(dy, fracLimbs: Self.fracLimbs)))
    }

    /// `self − other` as ordinary doubles (accurate when the two are close together).
    func difference(from o: Center) -> (dx: Double, dy: Double) {
        (x.subtracting(o.x).doubleValue, y.subtracting(o.y).doubleValue)
    }
}

// MARK: - Perturbation theory

/// Reference orbit Z₀, Z₁, … computed in high precision, stored as doubles.
final class Orbit {
    let re: [Double]
    let im: [Double]
    let computedIter: Int
    let escaped: Bool

    init(re: [Double], im: [Double], computedIter: Int, escaped: Bool) {
        self.re = re; self.im = im; self.computedIter = computedIter; self.escaped = escaped
    }
}

final class OrbitCache {
    static let shared = OrbitCache()

    private struct Entry {
        var kind: FractalKind
        var juliaRe: Double
        var juliaIm: Double
        var ref: Center
        var fracLimbs: Int
        var orbit: Orbit
    }

    private let lock = NSLock()
    private var entry: Entry?

    /// Returns an orbit valid for this view, plus the view-centre's offset from the orbit's reference point.
    func orbit(for p: FractalParams, size: CGSize) -> (orbit: Orbit, dx: Double, dy: Double) {
        let s = Double(p.scale)
        let needed = max(4, Int(ceil((log2(s) + 96) / 32)))
        let reach = 4 * Double(max(size.width, size.height)) / s // stay within a few screens of the reference

        lock.lock()
        if let e = entry, e.kind == p.kind, e.juliaRe == p.juliaC.re, e.juliaIm == p.juliaC.im,
           e.fracLimbs >= needed, e.orbit.escaped || e.orbit.computedIter >= p.maxIter {
            let d = p.center.difference(from: e.ref)
            if abs(d.dx) < reach && abs(d.dy) < reach {
                lock.unlock()
                return (e.orbit, d.dx, d.dy)
            }
        }
        lock.unlock()

        let orbit = Self.build(p, fracLimbs: needed)
        lock.lock()
        entry = Entry(kind: p.kind, juliaRe: p.juliaC.re, juliaIm: p.juliaC.im, ref: p.center,
                      fracLimbs: needed, orbit: orbit)
        lock.unlock()
        return (orbit, 0, 0)
    }

    private static func build(_ p: FractalParams, fracLimbs F: Int) -> Orbit {
        let rx = p.center.x.converted(fracLimbs: F), ry = p.center.y.converted(fracLimbs: F)
        let zero = BigFixed(fracLimbs: F)
        var zr = zero, zi = zero
        let cr: BigFixed, ci: BigFixed
        if p.kind == .julia {
            zr = rx
            zi = ry
            cr = BigFixed(p.juliaC.re, fracLimbs: F)
            ci = BigFixed(p.juliaC.im, fracLimbs: F)
        } else {
            cr = rx
            ci = ry
        }

        var re = [zr.doubleValue], im = [zi.doubleValue]
        re.reserveCapacity(p.maxIter + 1)
        im.reserveCapacity(p.maxIter + 1)
        var escaped = false
        for _ in 0..<max(1, p.maxIter) {
            let r2 = zr.multiplied(by: zr), i2 = zi.multiplied(by: zi), ri = zr.multiplied(by: zi)
            zr = r2.subtracting(i2).adding(cr)
            zi = ri.adding(ri).adding(ci)
            let a = zr.doubleValue, b = zi.doubleValue
            re.append(a); im.append(b)
            if a * a + b * b > 256 { escaped = true; break }
        }
        return Orbit(re: re, im: im, computedIter: p.maxIter, escaped: escaped)
    }
}

extension FractalRenderer {
    /// Deep-zoom rendering: each pixel is a small offset from one high-precision reference orbit,
    /// so only that one orbit needs big numbers.
    static func renderDeep(_ p: FractalParams, size: CGSize, cell: CGFloat) -> CGImage? {
        let s = Double(p.scale)
        let hw = Double(size.width) / 2, hh = Double(size.height) / 2
        let info = OrbitCache.shared.orbit(for: p, size: size)
        let isJulia = p.kind == .julia
        let cosR = cos(p.rotation), sinR = sin(p.rotation)
        return Raster.image(size: size, cell: cell) { sx, sy in
            let a = sx - hw, b = -(sy - hh)
            let ox = (a * cosR - b * sinR) / s + info.dx
            let oy = (a * sinR + b * cosR) / s + info.dy
            let mu = isJulia
                ? perturb(info.orbit, d0: (ox, oy), dc: (0, 0), maxIter: p.maxIter)
                : perturb(info.orbit, d0: (0, 0), dc: (ox, oy), maxIter: p.maxIter)
            guard mu >= 0 else { return (0, 0, 0) }
            return p.palette.color(forMu: mu, frequency: p.kind.colorFrequency)
        }
    }

    /// δₙ₊₁ = 2·Zₙ·δₙ + δₙ² + δc, rebasing onto the start of the orbit whenever δ stops being small.
    private static func perturb(_ orbit: Orbit, d0: (Double, Double), dc: (Double, Double), maxIter: Int) -> Double {
        var dr = d0.0, di = d0.1
        var n = 0, m = 0
        let last = orbit.re.count - 1
        while m < maxIter {
            let zr = orbit.re[n], zi = orbit.im[n]
            let ndr = 2 * (zr * dr - zi * di) + dr * dr - di * di + dc.0
            let ndi = 2 * (zr * di + zi * dr) + 2 * dr * di + dc.1
            dr = ndr; di = ndi
            n += 1; m += 1
            let fr = orbit.re[n] + dr, fi = orbit.im[n] + di
            let mag = fr * fr + fi * fi
            if mag > 256 { return Double(m) + 1 - log2(0.5 * log(mag)) }
            if mag < dr * dr + di * di || n == last {
                dr = fr - orbit.re[0]
                di = fi - orbit.im[0]
                n = 0
            }
        }
        return -1
    }
}
