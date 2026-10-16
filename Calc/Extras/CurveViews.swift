import SwiftUI

// MARK: - Lissajous

struct LissajousView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent
    @State private var a = 3.0
    @State private var b = 2.0
    @State private var phi = 0.8
    @State private var animate = true

    var body: some View {
        ExToolPage(info: ["tool.lissajous"]) {
            TimelineView(.animation(paused: !active || !animate)) { tl in
                Canvas { ctx, size in
                    let ph = animate ? phi + tl.date.timeIntervalSinceReferenceDate * 0.6 : phi
                    draw(&ctx, size, ph)
                }
            }
        } controls: {
            ExParamRow(title: "a", value: $a, range: 1...13, step: 1, format: "%.0f")
            ExParamRow(title: "b", value: $b, range: 1...13, step: 1, format: "%.0f")
            ExParamRow(title: "φ", value: $phi, range: 0...(2 * .pi), format: "%.2f")
            Toggle("Animate the phase", isOn: $animate)
            Text("x = sin(a·t),  y = sin(b·t + φ). Integer a:b closes the curve; the loops count a and b.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ ph: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        let rx = size.width * 0.42, ry = min(size.height * 0.34, size.width * 0.42)
        ctx.stroke(Path(CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry)),
                   with: .color(.secondary.opacity(0.25)), lineWidth: 1)
        let n = 2000
        var pts: [CGPoint] = []
        pts.reserveCapacity(n + 1)
        for i in 0...n {
            let t = Double(i) / Double(n) * 2 * .pi
            pts.append(CGPoint(x: c.x + rx * sin(a * t), y: c.y - ry * sin(b * t + ph)))
        }
        ctx.strokePolyline(pts, color: accent, width: 2.5)
    }
}

// MARK: - Rose

struct RoseView: View {
    @Environment(\.appAccent) private var accent
    @State private var k = 2.5

    /// Smallest q ≤ 60 such that k ≈ p/q; the rose closes after θ = 2πq.
    static func denominator(of k: Double) -> (p: Int, q: Int)? {
        for q in 1...60 {
            let p = (k * Double(q)).rounded()
            if abs(k - p / Double(q)) < 1e-4 { return (Int(p), q) }
        }
        return nil
    }

    var body: some View {
        ExToolPage(info: ["tool.rose"]) {
            Canvas { ctx, size in draw(&ctx, size) }
        } controls: {
            ExParamRow(title: "k", value: $k, range: 0.05...12, step: 0.05, format: "%.2f")
            Text(fractionText).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
            Text("r = cos(kθ). With k = p/q the curve closes after q turns. Irrational-looking k never closes, so it is drawn for 60 turns.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var fractionText: String {
        if let f = Self.denominator(of: k) {
            return f.q == 1 ? String(format: "k = %d  →  %d petals (odd k) or %d (even k)", f.p, f.p, 2 * f.p)
                            : "k = \(f.p)/\(f.q)"
        }
        return String(format: "k = %.2f (not a simple fraction)", k)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        let R = min(size.width * 0.44, size.height * 0.36)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R)),
                   with: .color(.secondary.opacity(0.2)), lineWidth: 1)
        let q = Self.denominator(of: k)?.q ?? 60
        let turns = Double(q)
        let n = min(30000, 500 * q + 800)
        var pts: [CGPoint] = []
        pts.reserveCapacity(n + 1)
        for i in 0...n {
            let th = Double(i) / Double(n) * 2 * .pi * turns
            let r = cos(k * th)
            pts.append(CGPoint(x: c.x + R * r * cos(th), y: c.y - R * r * sin(th)))
        }
        ctx.strokePolyline(pts, color: accent, width: q > 10 ? 1.2 : 2.2)
    }
}

// MARK: - Spirograph

struct SpirographView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent
    @State private var bigR = 60.0
    @State private var smallR = 17.0
    @State private var pen = 40.0
    @State private var epi = false
    @State private var gears = true

    private func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }

    /// Point of the curve at parameter t.
    private func point(_ t: Double, R: Double, r: Double, d: Double) -> (Double, Double) {
        if epi {
            let k = (R + r) / r
            return ((R + r) * cos(t) - d * cos(k * t), (R + r) * sin(t) - d * sin(k * t))
        }
        let k = (R - r) / r
        return ((R - r) * cos(t) + d * cos(k * t), (R - r) * sin(t) - d * sin(k * t))
    }

    var body: some View {
        ExToolPage(info: ["tool.spirograph"]) {
            TimelineView(.animation(paused: !active || !gears)) { tl in
                Canvas { ctx, size in
                    draw(&ctx, size, tl.date.timeIntervalSinceReferenceDate)
                }
            }
        } controls: {
            Picker("Type", selection: $epi) {
                Text("Hypotrochoid (inside)").tag(false)
                Text("Epitrochoid (outside)").tag(true)
            }
            .pickerStyle(.segmented)
            ExParamRow(title: "Ring R", value: $bigR, range: 10...100, step: 1, format: "%.0f")
            ExParamRow(title: "Gear r", value: $smallR, range: 1...100, step: 1, format: "%.0f")
            ExParamRow(title: "Pen d", value: $pen, range: 0...120, step: 1, format: "%.0f")
            Toggle("Show the rolling gear", isOn: $gears)
            Text(epi ? "Gear r rolls outside ring R; the pen sits d from the gear's centre."
                     : "Gear r rolls inside ring R; the pen sits d from the gear's centre.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let R = bigR, r = max(1, smallR), d = pen
        let g = max(1, gcd(Int(R), Int(r)))
        let turns = Double(Int(r) / g)
        let tMax = 2 * .pi * turns
        let extent = (epi ? R + r : abs(R - r)) + d
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        let s = min(size.width * 0.46, size.height * 0.38) / max(extent, 1)
        func pt(_ t: Double) -> CGPoint {
            let p = point(t, R: R, r: r, d: d)
            return CGPoint(x: c.x + s * p.0, y: c.y - s * p.1)
        }

        let n = min(40000, Int(turns) * 500 + 800)
        let progress = gears ? (time / 10).truncatingRemainder(dividingBy: 1) : 1
        let upTo = Int(Double(n) * progress)
        var all: [CGPoint] = []
        all.reserveCapacity(n + 1)
        for i in 0...n { all.append(pt(Double(i) / Double(n) * tMax)) }
        if gears {
            ctx.strokePolyline(all, color: .secondary.opacity(0.3), width: 1)
            ctx.strokePolyline(Array(all[0...upTo]), color: accent, width: 2.2)
        } else {
            ctx.strokePolyline(all, color: accent, width: 1.6)
        }

        guard gears else { return }
        // Ring and rolling gear at the current angle.
        let t = progress * tMax
        let ringR = CGFloat(R * s)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - ringR, y: c.y - ringR, width: 2 * ringR, height: 2 * ringR)),
                   with: .color(.secondary.opacity(0.4)), lineWidth: 1)
        let dist = epi ? R + r : R - r
        let gc = CGPoint(x: c.x + CGFloat(dist * cos(t) * s), y: c.y - CGFloat(dist * sin(t) * s))
        let gr = CGFloat(r * s)
        ctx.stroke(Path(ellipseIn: CGRect(x: gc.x - gr, y: gc.y - gr, width: 2 * gr, height: 2 * gr)),
                   with: .color(.primary.opacity(0.55)), lineWidth: 1.2)
        let p = pt(t)
        var arm = Path()
        arm.move(to: gc); arm.addLine(to: p)
        ctx.stroke(arm, with: .color(.primary.opacity(0.55)), lineWidth: 1)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(accent))
    }
}

// MARK: - Space-filling curves

struct SpaceFillingView: View {
    @Environment(\.appAccent) private var accent
    @State private var peano = false
    @State private var depth = 4.0

    /// Hilbert curve: index → (x, y) on a 2ᵏ × 2ᵏ grid.
    static func hilbert(_ n: Int, _ d: Int) -> (Int, Int) {
        var x = 0, y = 0, t = d, s = 1
        while s < n {
            let rx = 1 & (t / 2)
            let ry = 1 & (t ^ rx)
            if ry == 0 {
                if rx == 1 { x = s - 1 - x; y = s - 1 - y }
                swap(&x, &y)
            }
            x += s * rx; y += s * ry
            t /= 4; s *= 2
        }
        return (x, y)
    }

    /// Peano curve: index → (x, y) on a 3ᵏ × 3ᵏ grid, built from base-3 digits with reflections.
    static func peanoPoint(_ k: Int, _ d: Int) -> (Int, Int) {
        var digits = [Int](repeating: 0, count: 2 * k)
        var t = d
        for i in stride(from: 2 * k - 1, through: 0, by: -1) { digits[i] = t % 3; t /= 3 }
        var x = 0, y = 0
        for i in 0..<k {
            let a = digits[2 * i], b = digits[2 * i + 1]
            var sy = 0, sx = 0
            for j in stride(from: 1, through: 2 * i, by: 2) { sy += digits[j] }
            for j in stride(from: 0, through: 2 * i, by: 2) { sx += digits[j] }
            x = x * 3 + (sy % 2 == 0 ? a : 2 - a)
            y = y * 3 + (sx % 2 == 0 ? b : 2 - b)
        }
        return (x, y)
    }

    private var maxDepth: Double { peano ? 5 : 8 }

    var body: some View {
        ExToolPage(info: ["tool.spacefilling"]) {
            Canvas { ctx, size in draw(&ctx, size) }
        } controls: {
            Picker("Curve", selection: $peano) {
                Text("Hilbert").tag(false)
                Text("Peano").tag(true)
            }
            .pickerStyle(.segmented)
            ExParamRow(title: "Depth", value: $depth, range: 1...maxDepth, step: 1, format: "%.0f")
            Text(peano ? "Order \(Int(min(depth, 5))): \(Int(pow(9, min(depth, 5)))) points on a \(Int(pow(3, min(depth, 5)))) × \(Int(pow(3, min(depth, 5)))) grid"
                       : "Order \(Int(depth)): \(Int(pow(4, depth))) points on a \(Int(pow(2, depth))) × \(Int(pow(2, depth))) grid")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: peano) { _, isPeano in depth = min(depth, isPeano ? 5 : 8) }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let side = min(size.width * 0.92, size.height * 0.78)
        let origin = CGPoint(x: (size.width - side) / 2, y: size.height / 2 + 24 - side / 2)
        let k = Int(min(depth, maxDepth))
        let grid = peano ? Int(pow(3, Double(k))) : 1 << k
        let count = grid * grid
        let cell = side / CGFloat(grid)
        func p(_ d: Int) -> CGPoint {
            let (x, y) = peano ? Self.peanoPoint(k, d) : Self.hilbert(grid, d)
            return CGPoint(x: origin.x + (CGFloat(x) + 0.5) * cell, y: origin.y + side - (CGFloat(y) + 0.5) * cell)
        }
        let chunks = min(48, count)
        let per = max(1, count / chunks)
        var start = 0
        var i = 0
        while start < count {
            let end = min(count - 1, start + per)
            var path = Path()
            path.move(to: p(start))
            for d in (start + 1)...max(start + 1, end) where d < count { path.addLine(to: p(d)) }
            let hueShift = 0.6 * Double(i) / Double(chunks)
            ctx.stroke(path, with: .color(ExColor.shifted(accent, by: hueShift)),
                       style: StrokeStyle(lineWidth: max(0.8, min(3, cell * 0.35)), lineCap: .round, lineJoin: .round))
            start = end
            i += 1
            if end == count - 1 { break }
        }
    }
}
