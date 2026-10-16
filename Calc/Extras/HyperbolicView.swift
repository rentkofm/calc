import SwiftUI

/// Regular {p, q} tilings of the hyperbolic plane in the Poincaré disk: p-gons, q meeting at every vertex.
/// Dragging moves the whole tiling by a hyperbolic isometry (a Möbius transformation of the disk).
struct HyperbolicView: View {
    @Environment(\.appAccent) private var accent

    private struct Poly {
        var verts: [Cx]
        var center: Cx
        var layer: Int
    }

    /// Orientation-preserving isometry z ↦ (αz + β) / (β̄z + ᾱ) with |α|² − |β|² = 1.
    private struct Mobius {
        var alpha = Cx(1, 0)
        var beta = Cx.zero

        func apply(_ z: Cx) -> Cx { (alpha * z + beta) / (beta.conj * z + alpha.conj) }

        /// `self ∘ other`
        func after(_ o: Mobius) -> Mobius {
            Mobius(alpha: alpha * o.alpha + beta * o.beta.conj, beta: alpha * o.beta + beta * o.alpha.conj)
        }

        static func translation(_ w: Cx) -> Mobius {
            let s = 1 / (1 - w.abs2).squareRoot()
            return Mobius(alpha: Cx(s, 0), beta: w * s)
        }
    }

    @State private var p = 5.0
    @State private var q = 4.0
    @State private var depth = 3.0
    @State private var rotation = 0.0
    @State private var slices = true
    @State private var polys: [Poly] = []
    @State private var move = Mobius()
    @State private var lastDrag: CGSize?

    private var valid: Bool { (p - 2) * (q - 2) > 4 }

    // MARK: Geometry

    /// Circle orthogonal to the unit circle through a and b, or nil if the geodesic is a straight line.
    private static func geodesicCircle(_ a: Cx, _ b: Cx) -> (centre: Cx, radius: Double)? {
        let det = a.re * b.im - a.im * b.re
        guard abs(det) > 1e-9 else { return nil }
        let c1 = (a.abs2 + 1) / 2, c2 = (b.abs2 + 1) / 2
        let o = Cx((c1 * b.im - a.im * c2) / det, (a.re * c2 - c1 * b.re) / det)
        return (o, max(1e-9, o.abs2 - 1).squareRoot())
    }

    /// Inversion in a circle: the reflection of the hyperbolic plane across the geodesic it carries.
    private static func reflect(_ z: Cx, in circle: (centre: Cx, radius: Double)) -> Cx {
        let d = z - circle.centre
        return circle.centre + d * (circle.radius * circle.radius / d.abs2)
    }

    /// Builds the polygons out to `depth` layers by repeated reflection across edges.
    private func build() {
        guard valid else { polys = []; return }
        let pp = Int(p)
        let r = (cos(.pi / p + .pi / q) / cos(.pi / p - .pi / q)).squareRoot()
        let first = Poly(verts: (0..<pp).map { Cx.polar(r, 2 * .pi * Double($0) / Double(pp)) }, center: .zero, layer: 0)
        var all = [first]
        var seen: Set<String> = [key(first.center)]
        var frontier = [first]
        let maxCount = 5000
        for layer in 1...max(1, Int(depth)) {
            var next: [Poly] = []
            for poly in frontier {
                for i in 0..<pp {
                    let a = poly.verts[i], b = poly.verts[(i + 1) % pp]
                    let verts: [Cx], centre: Cx
                    if let circ = Self.geodesicCircle(a, b) {
                        verts = poly.verts.map { Self.reflect($0, in: circ) }
                        centre = Self.reflect(poly.center, in: circ)
                    } else {
                        // Edge on a line through the origin: reflect across that line.
                        let dir = (b - a) * (1 / (b - a).abs)
                        func mirror(_ z: Cx) -> Cx { dir * dir * z.conj }
                        verts = poly.verts.map(mirror)
                        centre = mirror(poly.center)
                    }
                    let k = key(centre)
                    if seen.contains(k) || all.count >= maxCount { continue }
                    seen.insert(k)
                    let np = Poly(verts: verts, center: centre, layer: layer)
                    next.append(np)
                    all.append(np)
                }
            }
            frontier = next
            if frontier.isEmpty || all.count >= maxCount { break }
        }
        polys = all
    }

    private func key(_ z: Cx) -> String { "\(Int((z.re * 1e4).rounded())),\(Int((z.im * 1e4).rounded()))" }

    // MARK: Body

    var body: some View {
        ExToolPage(info: ["tool.hyperbolic", "tool.poincare"], panelHeight: 230) {
            Canvas { ctx, size in draw(&ctx, size) }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { v in
                            let prev = lastDrag ?? .zero
                            let dx = Double(v.translation.width - prev.width), dy = Double(v.translation.height - prev.height)
                            lastDrag = v.translation
                            let r = 200.0
                            // Slide the tiling under the finger.
                            var w = Cx(dx / r, -dy / r)
                            if w.abs > 0.5 { w = w * (0.5 / w.abs) }
                            move = Mobius.translation(w).after(move)
                        }
                        .onEnded { _ in lastDrag = nil }
                )
        } controls: {
            ExParamRow(title: "p (sides)", value: $p, range: 3...12, step: 1, format: "%.0f")
            ExParamRow(title: "q (at vertex)", value: $q, range: 3...12, step: 1, format: "%.0f")
            ExParamRow(title: "Depth", value: $depth, range: 1...8, step: 1, format: "%.0f")
            ExParamRow(title: "Rotate", value: $rotation, range: 0...(2 * .pi), format: "%.2f")
            Toggle("Escher-style slices", isOn: $slices)
            GlassEffectContainer(spacing: 8) {
                Button { move = Mobius(); rotation = 0 } label: {
                    Label("Recentre", systemImage: "scope").frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.glass)
            }
            Text(valid ? "{\(Int(p)), \(Int(q))}: \(polys.count) tiles. Drag to glide through hyperbolic space."
                       : "{\(Int(p)), \(Int(q))} is not hyperbolic. It needs (p − 2)(q − 2) > 4; try p = 5, q = 4.")
                .font(.footnote).foregroundStyle(valid ? Color.secondary : Color.red)
        }
        .onAppear { build() }
        .onChange(of: p) { _, _ in build() }
        .onChange(of: q) { _, _ in build() }
        .onChange(of: depth) { _, _ in build() }
    }

    // MARK: Drawing

    /// Points along the hyperbolic geodesic from a to b, in screen coordinates.
    private func geodesic(_ a: Cx, _ b: Cx, mid: CGPoint, R: Double) -> [CGPoint] {
        func scr(_ z: Cx) -> CGPoint { CGPoint(x: mid.x + CGFloat(z.re * R), y: mid.y - CGFloat(z.im * R)) }
        guard let g = Self.geodesicCircle(a, b) else { return [scr(a), scr(b)] }
        let ta = atan2(a.im - g.centre.im, a.re - g.centre.re)
        let tb = atan2(b.im - g.centre.im, b.re - g.centre.re)
        var d = tb - ta
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        let px = hypot((a.re - b.re) * R, (a.im - b.im) * R)
        let n = max(1, min(14, Int(px / 7) + 1 + Int(abs(d) * 4)))
        return (0...n).map { i in
            let t = ta + d * Double(i) / Double(n)
            return scr(Cx(g.centre.re + g.radius * cos(t), g.centre.im + g.radius * sin(t)))
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let mid = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        let R = Double(min(size.width * 0.47, size.height * 0.40))
        ctx.fill(Path(ellipseIn: CGRect(x: mid.x - R, y: mid.y - R, width: 2 * R, height: 2 * R)),
                 with: .color(.black.opacity(0.55)))
        guard valid else { return }
        let rot = Cx.polar(1, rotation)
        let colours = (0..<4).map { ExColor.shifted(accent, by: Double($0) * 0.09, sat: 0.7, bri: 0.95) }

        // Draw outermost layers first so the large central tiles end up on top.
        for poly in polys.reversed() {
            let vs = poly.verts.map { move.apply($0 * rot) }
            let centre = move.apply(poly.center * rot)
            // Tiles that have shrunk to nothing near the rim aren't worth drawing.
            if vs.allSatisfy({ $0.abs > 0.9995 }) { continue }
            let base = colours[poly.layer % colours.count]
            let n = vs.count
            if slices {
                for i in 0..<n {
                    var path = Path()
                    var pts = [CGPoint(x: mid.x + CGFloat(centre.re * R), y: mid.y - CGFloat(centre.im * R))]
                    pts += geodesic(vs[i], vs[(i + 1) % n], mid: mid, R: R)
                    path.addLines(pts)
                    path.closeSubpath()
                    let bright = (i + poly.layer) % 2 == 0
                    ctx.fill(path, with: .color(bright ? base : ExColor.shifted(accent, by: 0.45, sat: 0.55, bri: 0.55)))
                }
            } else {
                var path = Path()
                var pts: [CGPoint] = []
                for i in 0..<n { pts += geodesic(vs[i], vs[(i + 1) % n], mid: mid, R: R) }
                path.addLines(pts)
                path.closeSubpath()
                ctx.fill(path, with: .color(poly.layer % 2 == 0 ? base : base.opacity(0.55)))
            }
            // Edges
            var edges = Path()
            for i in 0..<n { edges.addLines(geodesic(vs[i], vs[(i + 1) % n], mid: mid, R: R)) }
            ctx.stroke(edges, with: .color(.white.opacity(0.75)), lineWidth: 0.8)
        }
        ctx.stroke(Path(ellipseIn: CGRect(x: mid.x - R, y: mid.y - R, width: 2 * R, height: 2 * R)),
                   with: .color(.white.opacity(0.8)), lineWidth: 1.5)
    }
}
