import SwiftUI

// MARK: - Logistic map: cobweb diagram

struct CobwebView: View {
    @Environment(\.appAccent) private var accent
    @State private var r = 3.7
    @State private var x0 = 0.2
    @State private var iterations = 60.0

    private func f(_ x: Double) -> Double { r * x * (1 - x) }

    /// Long-run behaviour: the period of the attractor (if short) and the Lyapunov exponent.
    private var analysis: (text: String, lyapunov: Double) {
        var x = x0
        for _ in 0..<3000 { x = f(x) }
        var lyap = 0.0
        var orbit: [Double] = []
        for i in 0..<6000 {
            lyap += log(max(1e-300, abs(r * (1 - 2 * x))))
            x = f(x)
            if i >= 5936 { orbit.append(x) }
        }
        lyap /= 6000
        for p in 1...32 where orbit.count > p {
            if abs(orbit[orbit.count - 1] - orbit[orbit.count - 1 - p]) < 1e-7 {
                return (p == 1 ? "Settles to a fixed point x ≈ \(String(format: "%.4f", orbit.last ?? 0))"
                               : "Settles into a cycle of period \(p)", lyap)
            }
        }
        return (lyap > 0 ? "Chaotic: no short cycle" : "No short cycle found", lyap)
    }

    var body: some View {
        ExToolPage(info: ["tool.logistic", "tool.cobweb"]) {
            Canvas { ctx, size in draw(&ctx, size) }
        } controls: {
            ExParamRow(title: "r", value: $r, range: 0...4, format: "%.3f")
            ExParamRow(title: "x₀", value: $x0, range: 0.01...0.99, format: "%.3f")
            ExParamRow(title: "Steps", value: $iterations, range: 1...200, step: 1, format: "%.0f")
            let a = analysis
            Text(a.text).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "Lyapunov exponent λ ≈ %.3f  (λ > 0 means sensitive dependence: chaos)", a.lyapunov))
                .font(.footnote).foregroundStyle(.secondary)
            Text("xₙ₊₁ = r·xₙ(1 − xₙ). The cobweb bounces between the parabola and the diagonal y = x.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let side = min(size.width * 0.9, size.height * 0.74)
        let o = CGPoint(x: (size.width - side) / 2, y: size.height / 2 + 24 - side / 2)
        // y-axis scaled so the parabola's peak r/4 always fits.
        let yMax = max(1, r / 4)
        func P(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: o.x + CGFloat(x) * side, y: o.y + side - CGFloat(y / yMax) * side)
        }
        ctx.stroke(Path(CGRect(x: o.x, y: o.y, width: side, height: side)), with: .color(.secondary.opacity(0.3)), lineWidth: 1)
        // y = x
        var diag = Path()
        diag.move(to: P(0, 0)); diag.addLine(to: P(1, 1))
        ctx.stroke(diag, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        // parabola
        var par = Path()
        for i in 0...200 {
            let x = Double(i) / 200
            let p = P(x, f(x))
            if i == 0 { par.move(to: p) } else { par.addLine(to: p) }
        }
        ctx.stroke(par, with: .color(.primary.opacity(0.8)), lineWidth: 2)
        // cobweb
        var web = Path()
        var x = x0
        web.move(to: P(x, 0))
        for _ in 0..<Int(iterations) {
            let y = f(x)
            web.addLine(to: P(x, y))
            web.addLine(to: P(y, y))
            x = y
        }
        ctx.stroke(web, with: .color(accent), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        let start = P(x0, 0)
        ctx.fill(Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)), with: .color(accent))
        ctx.draw(Text("x").font(.caption).foregroundStyle(.secondary), at: CGPoint(x: o.x + side + 8, y: o.y + side))
        ctx.draw(Text("xₙ₊₁").font(.caption).foregroundStyle(.secondary), at: CGPoint(x: o.x + 6, y: o.y - 8))
    }
}

// MARK: - Bifurcation diagram

struct BifurcationView: View {
    let active: Bool

    private struct Window: Equatable {
        var rMin: Double, rMax: Double, xMin: Double, xMax: Double
    }

    @Environment(\.appAccent) private var accent
    @Environment(\.displayScale) private var displayScale
    @State private var window = Window(rMin: 2.5, rMax: 4.0, xMin: 0, xMax: 1)
    @State private var imageWindow = Window(rMin: 2.5, rMax: 4.0, xMin: 0, xMax: 1)
    @State private var image: CGImage?
    @State private var size: CGSize = .zero
    @State private var generation = 0
    @State private var dragOrigin: Window?
    @State private var zoomOrigin: Window?
    @State private var showMarks = true

    /// Period-doubling points of the logistic map (the Feigenbaum cascade).
    private static let marks: [(r: Double, label: String)] = [
        (3.0, "r₁ = 3"), (3.449490, "r₂"), (3.544090, "r₃"), (3.564407, "r₄"), (3.568759, "r₅"),
        (3.569692, "r₆"), (3.5699456, "r∞ ≈ 3.5699"),
    ]

    // MARK: Rendering

    private static func makeImage(window w: Window, width: Int, height: Int, hue: Double) -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        var hist = [UInt32](repeating: 0, count: width * height)
        let span = w.rMax - w.rMin
        let zoom = max(0, log2(1.5 / max(span, 1e-12)))
        let warm = min(8000, 600 + Int(zoom * 250))
        let samples = 700
        hist.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: width) { i in
                let r = w.rMin + (Double(i) + 0.5) / Double(width) * span
                var x = 0.5
                for _ in 0..<warm { x = r * x * (1 - x) }
                for _ in 0..<samples {
                    x = r * x * (1 - x)
                    let fy = (x - w.xMin) / (w.xMax - w.xMin)
                    guard fy >= 0, fy < 1 else { continue }
                    let j = height - 1 - Int(fy * Double(height))
                    base[j * width + i] &+= 1
                }
            }
        }
        let peak = Double(max(1, hist.max() ?? 1))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let denom = log(1 + min(peak, 40))
        for k in 0..<(width * height) {
            let c = hist[k]
            guard c > 0 else { continue }
            let v = min(1, log(1 + Double(min(c, 40))) / denom)
            let (r, g, b) = PendulumPalette.hsv(hue + 0.08 * v, 0.65 - 0.5 * v * v, 0.35 + 0.65 * v)
            rgba[k * 4] = r; rgba[k * 4 + 1] = g; rgba[k * 4 + 2] = b; rgba[k * 4 + 3] = 255
        }
        return Raster.cgImage(width: width, height: height, rgba: rgba)
    }

    private func render() {
        guard size.width > 0 else { return }
        generation += 1
        let g = generation
        let w = window
        let scale = min(displayScale, 2)
        let pw = Int(size.width * scale), ph = Int(size.height * scale)
        let hue = ExColor.hue(of: accent)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard g == generation else { return }
            let img = await Task.detached(priority: .userInitiated) {
                Self.makeImage(window: w, width: pw, height: ph, hue: hue)
            }.value
            guard g == generation, let img else { return }
            image = img
            imageWindow = w
        }
    }

    private func jump(_ w: Window) { window = w }

    // MARK: Body

    var body: some View {
        ExToolPage(info: ["tool.bifurcation", "tool.feigenbaum", "tool.logistic"], panelHeight: 200) {
            ZStack {
                Color.black.opacity(0.85)
                Canvas { ctx, sz in draw(&ctx, sz) }
            }
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        if dragOrigin == nil { dragOrigin = window }
                        guard let o = dragOrigin, size.width > 0 else { return }
                        let dr = -Double(v.translation.width) / Double(size.width) * (o.rMax - o.rMin)
                        let dx = Double(v.translation.height) / Double(size.height) * (o.xMax - o.xMin)
                        window = Window(rMin: o.rMin + dr, rMax: o.rMax + dr, xMin: o.xMin + dx, xMax: o.xMax + dx)
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if zoomOrigin == nil { zoomOrigin = window }
                        guard let o = zoomOrigin else { return }
                        let k = 1 / max(0.05, Double(v.magnification))
                        let rc = (o.rMin + o.rMax) / 2, xc = (o.xMin + o.xMax) / 2
                        let hr = (o.rMax - o.rMin) / 2 * k, hx = (o.xMax - o.xMin) / 2 * k
                        guard hr > 1e-10, hr < 20 else { return }
                        window = Window(rMin: rc - hr, rMax: rc + hr, xMin: xc - hx, xMax: xc + hx)
                    }
                    .onEnded { _ in zoomOrigin = nil }
            )
        } controls: {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip("Full") { jump(Window(rMin: 2.5, rMax: 4, xMin: 0, xMax: 1)) }
                    chip("Cascade") { jump(Window(rMin: 3.4, rMax: 3.6, xMin: 0.3, xMax: 0.9)) }
                    chip("Period 3") { jump(Window(rMin: 3.8, rMax: 3.9, xMin: 0.1, xMax: 0.98)) }
                }
            }
            Toggle("Mark the period-doubling points", isOn: $showMarks)
            Text(String(format: "r ∈ [%.5f, %.5f]   x ∈ [%.3f, %.3f]", window.rMin, window.rMax, window.xMin, window.xMax))
                .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            Text("Drag to pan, pinch to zoom. Each period-doubling interval is about 4.669× shorter than the last (Feigenbaum's δ).")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: window) { _, _ in render() }
        .onChange(of: size) { _, _ in render() }
        .onChange(of: accent) { _, _ in render() }
        .onAppear { render() }
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity, minHeight: 30) }.buttonStyle(.glass)
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ sz: CGSize) {
        // Draw the last rendered image where its window now sits inside the current one, so panning and
        // zooming move the picture immediately while a sharp one renders.
        if let image {
            let iw = imageWindow, w = window
            let x0 = (iw.rMin - w.rMin) / (w.rMax - w.rMin) * sz.width
            let x1 = (iw.rMax - w.rMin) / (w.rMax - w.rMin) * sz.width
            let y0 = (w.xMax - iw.xMax) / (w.xMax - w.xMin) * sz.height
            let y1 = (w.xMax - iw.xMin) / (w.xMax - w.xMin) * sz.height
            ctx.draw(Image(decorative: image, scale: 1),
                     in: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
        }
        guard showMarks else { return }
        for m in Self.marks {
            let x = (m.r - window.rMin) / (window.rMax - window.rMin) * sz.width
            guard x > 0, x < sz.width else { continue }
            var line = Path()
            line.move(to: CGPoint(x: x, y: 70)); line.addLine(to: CGPoint(x: x, y: sz.height))
            ctx.stroke(line, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            ctx.draw(Text(m.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.8)),
                     at: CGPoint(x: min(max(x, 30), sz.width - 30), y: 80))
        }
    }
}
