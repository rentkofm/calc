import SwiftUI

/// Fractals drawn as paths. Everything is culled to the visible region, so zooming stays cheap.
enum VectorFractals {
    typealias V = SIMD2<Double>

    struct View2D {
        var cx: Double, cy: Double, s: Double
        var hw: Double, hh: Double

        init(center: Center, scale: Double, size: CGSize) {
            cx = center.doubleX; cy = center.doubleY; s = scale
            hw = Double(size.width) / 2; hh = Double(size.height) / 2
        }

        var minX: Double { cx - hw / s }
        var maxX: Double { cx + hw / s }
        var minY: Double { cy - hh / s }
        var maxY: Double { cy + hh / s }

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: hw + (x - cx) * s, y: hh - (y - cy) * s)
        }

        func intersects(minx: Double, maxx: Double, miny: Double, maxy: Double) -> Bool {
            !(maxx < minX || minx > maxX || maxy < minY || miny > maxY)
        }
    }

    static func draw(_ ctx: GraphicsContext, size: CGSize, p: FractalParams) {
        let v = View2D(center: p.center, scale: Double(p.scale), size: size)
        switch p.kind {
        case .hilbert, .peano: drawSpaceFilling(ctx, size, v, p)
        case .pythagoras: drawPythagoras(ctx, size, v, p)
        case .apollonian: drawApollonian(ctx, size, v, p)
        default: drawLSystem(ctx, size, v, p)
        }
    }

    // MARK: Hilbert & Peano

    private struct CurveBuilder {
        var path = Path()
        var needMove = true
        let v: View2D
        let peano: Bool

        mutating func point(_ x: Double, _ y: Double) {
            let p = v.point(x, y)
            if needMove { path.move(to: p); needMove = false } else { path.addLine(to: p) }
        }

        /// A cell spanned by basis vectors (xi, xj) and (yi, yj) from (x0, y0).
        mutating func cell(_ x0: Double, _ y0: Double, _ xi: Double, _ xj: Double,
                           _ yi: Double, _ yj: Double, _ depth: Int) {
            let minx = min(min(x0, x0 + xi), min(x0 + yi, x0 + xi + yi))
            let maxx = max(max(x0, x0 + xi), max(x0 + yi, x0 + xi + yi))
            let miny = min(min(y0, y0 + xj), min(y0 + yj, y0 + xj + yj))
            let maxy = max(max(y0, y0 + xj), max(y0 + yj, y0 + xj + yj))
            if !v.intersects(minx: minx, maxx: maxx, miny: miny, maxy: maxy) { needMove = true; return }

            let size = max(hypot(xi, xj), hypot(yi, yj)) * v.s
            if size < 3 || depth >= 45 { point(x0 + (xi + yi) / 2, y0 + (xj + yj) / 2); return }

            if peano {
                for c in 0..<3 {
                    for r0 in 0..<3 {
                        let r = c % 2 == 0 ? r0 : 2 - r0
                        var ox = x0 + xi * Double(c) / 3 + yi * Double(r) / 3
                        var oy = y0 + xj * Double(c) / 3 + yj * Double(r) / 3
                        var bxi = xi / 3, bxj = xj / 3, byi = yi / 3, byj = yj / 3
                        if r % 2 == 1 { ox += bxi; oy += bxj; bxi = -bxi; bxj = -bxj }
                        if c % 2 == 1 { ox += byi; oy += byj; byi = -byi; byj = -byj }
                        cell(ox, oy, bxi, bxj, byi, byj, depth + 1)
                    }
                }
            } else {
                cell(x0, y0, yi / 2, yj / 2, xi / 2, xj / 2, depth + 1)
                cell(x0 + xi / 2, y0 + xj / 2, xi / 2, xj / 2, yi / 2, yj / 2, depth + 1)
                cell(x0 + xi / 2 + yi / 2, y0 + xj / 2 + yj / 2, xi / 2, xj / 2, yi / 2, yj / 2, depth + 1)
                cell(x0 + xi / 2 + yi, y0 + xj / 2 + yj, -yi / 2, -yj / 2, -xi / 2, -xj / 2, depth + 1)
            }
        }
    }

    private static func drawSpaceFilling(_ ctx: GraphicsContext, _ size: CGSize, _ v: View2D, _ p: FractalParams) {
        var b = CurveBuilder(v: v, peano: p.kind == .peano)
        b.cell(0, 0, 1, 0, 0, 1, 0)
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: p.palette.lineColors(6)),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
        ctx.stroke(b.path, with: shading, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }

    // MARK: Pythagoras tree

    private struct TreeBuilder {
        var buckets: [Path]
        let v: View2D
        let maxDepth: Int
        let cosT: Double, sinT: Double
        var nodes = 0

        mutating func square(_ p0: V, _ p1: V, _ depth: Int) {
            nodes += 1
            if nodes > 200_000 { return }
            let u = p1 - p0
            let side = (u.x * u.x + u.y * u.y).squareRoot()
            if side * v.s < 0.7 { return }
            let n = V(-u.y, u.x)
            let p2 = p1 + n, p3 = p0 + n

            // Everything below this square fits within a few side lengths of it.
            let mid = (p0 + p2) * 0.5, r = side * 3.4
            if !v.intersects(minx: mid.x - r, maxx: mid.x + r, miny: mid.y - r, maxy: mid.y + r) { return }

            var poly = Path()
            poly.move(to: v.point(p0.x, p0.y))
            poly.addLine(to: v.point(p1.x, p1.y))
            poly.addLine(to: v.point(p2.x, p2.y))
            poly.addLine(to: v.point(p3.x, p3.y))
            poly.closeSubpath()
            buckets[min(depth, buckets.count - 1)].addPath(poly)

            if depth >= maxDepth { return }
            // Right triangle on the top edge; its apex splits that edge into two new squares.
            let apex = p3 + (u * cosT + n * sinT) * cosT
            square(p3, apex, depth + 1)
            square(apex, p2, depth + 1)
        }
    }

    private static func drawPythagoras(_ ctx: GraphicsContext, _ size: CGSize, _ v: View2D, _ p: FractalParams) {
        let theta = p.power * Double.pi / 180
        let depth = max(1, Int(p.maxIter))
        var b = TreeBuilder(buckets: [Path](repeating: Path(), count: depth + 1), v: v, maxDepth: depth,
                            cosT: cos(theta), sinT: sin(theta))
        b.square(V(-0.5, 0), V(0.5, 0), 0)
        for (d, path) in b.buckets.enumerated() {
            let t = Double(d) / Double(max(depth, 1))
            ctx.fill(path, with: .color(p.palette.swiftUIColor(at: p.palette == .deepBlue ? 0.35 + 0.6 * t : t)))
            ctx.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 0.5)
        }
    }

    // MARK: Apollonian gasket

    private struct Disc {
        var k: Double   // signed curvature (negative for the enclosing circle)
        var kx: Double  // curvature × center
        var ky: Double

        var radius: Double { 1 / abs(k) }
        var cx: Double { kx / k }
        var cy: Double { ky / k }
    }

    private struct GasketBuilder {
        var buckets: [Path]
        let v: View2D
        var nodes = 0

        func visible(_ c: Disc) -> Bool {
            let r = c.radius
            return v.intersects(minx: c.cx - r, maxx: c.cx + r, miny: c.cy - r, maxy: c.cy + r)
        }

        mutating func add(_ c: Disc, _ depth: Int) {
            guard visible(c) else { return }
            let r = c.radius
            let rect = CGRect(x: v.point(c.cx, c.cy).x - r * v.s, y: v.point(c.cx, c.cy).y - r * v.s,
                              width: 2 * r * v.s, height: 2 * r * v.s)
            buckets[min(depth, buckets.count - 1)].addEllipse(in: rect)
        }

        /// `d` was just added; each of a, b, c can be swapped for the circle tangent to the other three.
        mutating func grow(_ a: Disc, _ b: Disc, _ c: Disc, _ d: Disc, _ depth: Int) {
            for (drop, p, q) in [(a, b, c), (b, a, c), (c, a, b)] {
                nodes += 1
                if nodes > 250_000 { return }
                let new = Disc(k: 2 * (p.k + q.k + d.k) - drop.k,
                                 kx: 2 * (p.kx + q.kx + d.kx) - drop.kx,
                                 ky: 2 * (p.ky + q.ky + d.ky) - drop.ky)
                if new.radius * v.s < 0.4 { continue }
                // Descendants stay within the gap bounded by p, q and d.
                var minx = Double.infinity, maxx = -Double.infinity
                var miny = Double.infinity, maxy = -Double.infinity
                for disc in [p, q, d] {
                    let r: Double = disc.radius
                    let x: Double = disc.cx, y: Double = disc.cy
                    minx = min(minx, x - r); maxx = max(maxx, x + r)
                    miny = min(miny, y - r); maxy = max(maxy, y + r)
                }
                if !v.intersects(minx: minx, maxx: maxx, miny: miny, maxy: maxy) { continue }
                add(new, depth)
                grow(p, q, d, new, depth + 1)
            }
        }
    }

    private static func drawApollonian(_ ctx: GraphicsContext, _ size: CGSize, _ v: View2D, _ p: FractalParams) {
        var b = GasketBuilder(buckets: [Path](repeating: Path(), count: 40), v: v)
        let outer = Disc(k: -1, kx: 0, ky: 0)
        let right = Disc(k: 2, kx: 1, ky: 0)
        let left = Disc(k: 2, kx: -1, ky: 0)
        let top = Disc(k: 3, kx: 0, ky: 2)
        let bottom = Disc(k: 3, kx: 0, ky: -2)
        for (i, c) in [outer, right, left, top, bottom].enumerated() { b.add(c, min(i, 1)) }
        b.grow(outer, right, left, top, 2)
        b.grow(outer, right, left, bottom, 2)
        for (d, path) in b.buckets.enumerated() where !path.isEmpty {
            let t = Double(d) * 0.07
            ctx.fill(path, with: .color(p.palette.swiftUIColor(at: p.palette == .deepBlue ? 0.35 + 0.6 * min(1, t) : t).opacity(0.85)))
            ctx.stroke(path, with: .color(.black.opacity(0.45)), lineWidth: 0.5)
        }
    }

    // MARK: L-systems

    private struct Segment {
        var x0: Float, y0: Float, x1: Float, y1: Float
        var level: UInt8
    }

    private struct LSystemSpec {
        var axiom: String
        var rules: [Character: String]
        var angle: Double
        var startAngle: Double
    }

    private static func spec(_ kind: FractalKind) -> LSystemSpec {
        switch kind {
        case .lTree:
            return LSystemSpec(axiom: "F", rules: ["F": "FF+[+F-F-F]-[-F+F+F]"], angle: 22.5, startAngle: 90)
        case .lArrowhead:
            return LSystemSpec(axiom: "A", rules: ["A": "B-A-B", "B": "A+B+A"], angle: 60, startAngle: 0)
        default:
            return LSystemSpec(axiom: "X", rules: ["X": "F+[[X]-X]-F[-FX]+X", "F": "FF"], angle: 25, startAngle: 90)
        }
    }

    private static let cacheLock = NSLock()
    private static var cache: [String: [Segment]] = [:]

    /// Expands the rules and walks a turtle over the result; coordinates are normalized to fit [-0.5, 0.5].
    private static func segments(_ kind: FractalKind, depth: Int) -> [Segment] {
        let key = "\(kind.rawValue)-\(depth)"
        cacheLock.lock()
        if let hit = cache[key] { cacheLock.unlock(); return hit }
        cacheLock.unlock()

        let sp = spec(kind)
        var text = Array(sp.axiom)
        for _ in 0..<depth {
            var next: [Character] = []
            for ch in text {
                if let r = sp.rules[ch] { next.append(contentsOf: r) } else { next.append(ch) }
            }
            if next.count > 500_000 { break }
            text = next
        }

        var segs: [Segment] = []
        var x = 0.0, y = 0.0, heading = sp.startAngle * Double.pi / 180
        var stack: [(Double, Double, Double)] = []
        let turn = sp.angle * Double.pi / 180
        for ch in text {
            switch ch {
            case "F", "A", "B":
                let nx = x + cos(heading), ny = y + sin(heading)
                segs.append(Segment(x0: Float(x), y0: Float(y), x1: Float(nx), y1: Float(ny),
                                    level: UInt8(min(stack.count, 255))))
                x = nx; y = ny
            case "+": heading += turn
            case "-": heading -= turn
            case "[": stack.append((x, y, heading))
            case "]": if let s = stack.popLast() { (x, y, heading) = s }
            default: break
            }
        }

        if !segs.isEmpty {
            var lo = SIMD2<Float>(.infinity, .infinity), hi = SIMD2<Float>(-.infinity, -.infinity)
            for s in segs {
                lo = pointwiseMin(lo, SIMD2(s.x0, s.y0)); lo = pointwiseMin(lo, SIMD2(s.x1, s.y1))
                hi = pointwiseMax(hi, SIMD2(s.x0, s.y0)); hi = pointwiseMax(hi, SIMD2(s.x1, s.y1))
            }
            let mid = (lo + hi) / 2
            let extent = max(hi.x - lo.x, hi.y - lo.y, 1e-6)
            for i in segs.indices {
                segs[i].x0 = (segs[i].x0 - mid.x) / extent; segs[i].x1 = (segs[i].x1 - mid.x) / extent
                segs[i].y0 = (segs[i].y0 - mid.y) / extent; segs[i].y1 = (segs[i].y1 - mid.y) / extent
            }
        }

        cacheLock.lock()
        cache[key] = segs
        cacheLock.unlock()
        return segs
    }

    private static func drawLSystem(_ ctx: GraphicsContext, _ size: CGSize, _ v: View2D, _ p: FractalParams) {
        let segs = segments(p.kind, depth: max(1, Int(p.maxIter)))
        var buckets = [Path](repeating: Path(), count: 8)
        let (minX, maxX, minY, maxY) = (v.minX, v.maxX, v.minY, v.maxY)
        for s in segs {
            let (x0, y0, x1, y1) = (Double(s.x0), Double(s.y0), Double(s.x1), Double(s.y1))
            if max(x0, x1) < minX || min(x0, x1) > maxX || max(y0, y1) < minY || min(y0, y1) > maxY { continue }
            let b = min(Int(s.level), buckets.count - 1)
            buckets[b].move(to: v.point(x0, y0))
            buckets[b].addLine(to: v.point(x1, y1))
        }
        for (level, path) in buckets.enumerated() where !path.isEmpty {
            let t = Double(level) / 7
            let color = p.palette.swiftUIColor(at: p.palette == .deepBlue ? 0.45 + 0.5 * t : t)
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: max(0.8, 2.6 - Double(level) * 0.3), lineCap: .round, lineJoin: .round))
        }
    }
}
