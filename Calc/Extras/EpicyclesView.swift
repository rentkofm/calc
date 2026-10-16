import SwiftUI

/// Draw any closed path; its discrete Fourier transform becomes a chain of rotating circles that redraws it.
struct EpicyclesView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent

    private struct Term { var k: Int; var c: Cx }

    @State private var coeffs: [Term] = []
    @State private var terms = 40.0
    @State private var speed = 0.12            // cycles per second
    @State private var showCircles = true
    @State private var drawing = false
    @State private var raw: [CGPoint] = []
    @State private var canvasSize: CGSize = .zero
    @State private var trace: [Cx] = []
    @State private var shapeName = "Heart"

    private static let samples = 256
    private static let shapes = ["Heart", "Star", "Trefoil", "Infinity", "Square", "Treble"]

    // MARK: Shapes

    private static func shape(_ name: String) -> [Cx] {
        let n = samples
        return (0..<n).map { (i: Int) -> Cx in
            let t = Double(i) / Double(n) * 2 * .pi
            switch name {
            case "Star":
                // Five-pointed star, drawn as a closed polygon through its points.
                let seg = Double(i) / Double(n) * 5
                let a = Int(seg) % 5, f = seg - floor(seg)
                func v(_ j: Int) -> Cx { Cx.polar(1, .pi / 2 + Double(j) * 4 * .pi / 5) }
                let p = v(a), q = v(a + 1)
                return p + (q - p) * f
            case "Trefoil":
                return Cx(sin(t) + 2 * sin(2 * t), cos(t) - 2 * cos(2 * t))
            case "Infinity":
                return Cx(cos(t) / (1 + sin(t) * sin(t)), sin(t) * cos(t) / (1 + sin(t) * sin(t)))
            case "Square":
                let seg = Double(i) / Double(n) * 4
                let side = Int(seg) % 4, f = seg - floor(seg)
                let corners = [Cx(1, 1), Cx(-1, 1), Cx(-1, -1), Cx(1, -1)]
                let p = corners[side], q = corners[(side + 1) % 4]
                return p + (q - p) * f
            case "Treble":
                // A looping spiral figure: epicycles of epicycles.
                return Cx.polar(1, t) + Cx.polar(0.5, 3 * t) + Cx.polar(0.25, -5 * t)
            default:
                return Cx(16 * pow(sin(t), 3),
                          13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
            }
        }
    }

    /// Centres the path on its centroid and scales it so the farthest point is at distance 1.
    private static func normalized(_ pts: [Cx]) -> [Cx] {
        guard !pts.isEmpty else { return pts }
        let m = pts.reduce(Cx.zero, +) * (1 / Double(pts.count))
        let shifted = pts.map { $0 - m }
        let r = max(1e-9, shifted.map(\.abs).max() ?? 1)
        return shifted.map { $0 * (1 / r) }
    }

    /// Discrete Fourier transform, strongest circles first.
    private static func dft(_ z: [Cx]) -> [Term] {
        let n = z.count
        var out: [Term] = []
        for k in -(n / 2)..<(n / 2) {
            var sum = Cx.zero
            for j in 0..<n { sum = sum + z[j] * Cx.polar(1, -2 * .pi * Double(k * j) / Double(n)) }
            out.append(Term(k: k, c: sum * (1 / Double(n))))
        }
        return out.sorted { $0.c.abs > $1.c.abs }
    }

    private func load(_ pts: [Cx]) {
        coeffs = Self.dft(Self.normalized(pts))
        rebuildTrace()
    }

    private func rebuildTrace() {
        let m = max(1, min(coeffs.count, Int(terms)))
        trace = (0...300).map { (i: Int) -> Cx in position(Double(i) / 300, m).last ?? .zero }
    }

    /// Centres of the circles at time t (cycles) for the first m terms; the last is the pen tip.
    private func position(_ t: Double, _ m: Int) -> [Cx] {
        var p = Cx.zero
        var out: [Cx] = [p]
        for i in 0..<min(m, coeffs.count) {
            p = p + coeffs[i].c * Cx.polar(1, 2 * .pi * Double(coeffs[i].k) * t)
            out.append(p)
        }
        return out
    }

    // MARK: Body

    var body: some View {
        ExToolPage(info: ["tool.epicycles"]) {
            TimelineView(.animation(paused: !active || drawing)) { tl in
                Canvas { ctx, size in draw(&ctx, size, tl.date.timeIntervalSinceReferenceDate) }
            }
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { canvasSize = $0 })
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in if drawing { raw.append(v.location) } }
                    .onEnded { _ in if drawing { finishDrawing() } }
            )
        } controls: {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        drawing.toggle()
                        raw = []
                    } label: {
                        Label(drawing ? "Cancel" : "Draw your own", systemImage: drawing ? "xmark" : "scribble")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(drawing ? .glass : .glassProminent)

                    Menu {
                        ForEach(Self.shapes, id: \.self) { name in
                            Button(name) { shapeName = name; drawing = false; load(Self.shape(name)) }
                        }
                    } label: {
                        Label(shapeName, systemImage: "square.on.circle").frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)
                }
            }
            ExParamRow(title: "Circles", value: $terms, range: 1...Double(Self.samples), step: 1, format: "%.0f")
                .onChange(of: terms) { _, _ in rebuildTrace() }
            ExParamRow(title: "Speed", value: $speed, range: 0.02...0.6, format: "%.2f/s")
            Toggle("Show the circles", isOn: $showCircles)
            Text(drawing ? "Draw one closed loop with your finger, then lift."
                         : "Few circles give a rough sketch; more circles sharpen the shape. Corners need many.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onAppear { if coeffs.isEmpty { load(Self.shape("Heart")) } }
    }

    private func finishDrawing() {
        defer { drawing = false; raw = [] }
        guard raw.count > 8, canvasSize.width > 0 else { return }
        // Close the loop and resample evenly by arc length.
        var pts = raw
        pts.append(raw[0])
        var lengths: [Double] = [0]
        for i in 1..<pts.count { lengths.append(lengths[i - 1] + Double(hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y))) }
        guard let total = lengths.last, total > 1 else { return }
        var out: [Cx] = []
        var j = 0
        for i in 0..<Self.samples {
            let target = total * Double(i) / Double(Self.samples)
            while j < lengths.count - 2 && lengths[j + 1] < target { j += 1 }
            let span = max(1e-9, lengths[j + 1] - lengths[j])
            let f = (target - lengths[j]) / span
            let x = Double(pts[j].x) + (Double(pts[j + 1].x) - Double(pts[j].x)) * f
            let y = Double(pts[j].y) + (Double(pts[j + 1].y) - Double(pts[j].y)) * f
            out.append(Cx(x, -y))
        }
        shapeName = "Your drawing"
        load(out)
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        let s = min(size.width * 0.42, size.height * 0.34)
        func px(_ z: Cx) -> CGPoint { CGPoint(x: c.x + CGFloat(z.re) * s, y: c.y - CGFloat(z.im) * s) }

        if drawing {
            ctx.strokePolyline(raw, color: accent, width: 3)
            if raw.isEmpty {
                ctx.draw(Text("Draw a closed shape").font(.headline).foregroundStyle(.secondary), at: c)
            }
            return
        }
        guard !coeffs.isEmpty else { return }

        let t = (time * speed).truncatingRemainder(dividingBy: 1)
        let m = max(1, min(coeffs.count, Int(terms)))
        let centres = position(t, m)

        // Path traced so far.
        let upTo = Int(t * 300)
        if upTo > 1 { ctx.strokePolyline(trace[0...upTo].map(px), color: accent, width: 2.5) }
        ctx.strokePolyline(trace.map(px), color: accent.opacity(0.18), width: 1)

        if showCircles {
            var circles = Path(), arms = Path()
            for i in 0..<min(m, 120) {
                let ctr = px(centres[i])
                let r = CGFloat(coeffs[i].c.abs) * s
                if r > 0.6 { circles.addEllipse(in: CGRect(x: ctr.x - r, y: ctr.y - r, width: 2 * r, height: 2 * r)) }
                arms.move(to: ctr)
                arms.addLine(to: px(centres[i + 1]))
            }
            ctx.stroke(circles, with: .color(.secondary.opacity(0.35)), lineWidth: 0.8)
            ctx.stroke(arms, with: .color(.primary.opacity(0.6)), lineWidth: 1.2)
        }
        let tip = px(centres[centres.count - 1])
        ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 4, y: tip.y - 4, width: 8, height: 8)), with: .color(accent))
    }
}
