import SwiftUI

// MARK: - Taylor / Maclaurin series

struct TaylorSeriesView: View {
    @Environment(\.appAccent) private var accent

    enum Function: String, CaseIterable, Identifiable {
        case sin = "sin x", cos = "cos x", exp = "eˣ", ln = "ln(1+x)", atan = "arctan x", geo = "1/(1−x)"
        var id: String { rawValue }

        func exact(_ x: Double) -> Double {
            switch self {
            case .sin: return Foundation.sin(x)
            case .cos: return Foundation.cos(x)
            case .exp: return Foundation.exp(x)
            case .ln: return x > -1 ? Foundation.log(1 + x) : .nan
            case .atan: return Foundation.atan(x)
            case .geo: return x == 1 ? .nan : 1 / (1 - x)
            }
        }

        /// Sum of the first `terms` non-zero terms of the Maclaurin series.
        func series(_ x: Double, _ terms: Int) -> Double {
            var sum = 0.0
            switch self {
            case .sin:
                var t = x
                for k in 0..<terms { sum += t; t *= -x * x / Double((2 * k + 2) * (2 * k + 3)) }
            case .cos:
                var t = 1.0
                for k in 0..<terms { sum += t; t *= -x * x / Double((2 * k + 1) * (2 * k + 2)) }
            case .exp:
                var t = 1.0
                for k in 0..<terms { sum += t; t *= x / Double(k + 1) }
            case .ln:
                var p = x
                for k in 1...max(1, terms) { sum += (k % 2 == 1 ? 1 : -1) * p / Double(k); p *= x }
            case .atan:
                var p = x
                for k in 0..<terms { sum += (k % 2 == 0 ? 1 : -1) * p / Double(2 * k + 1); p *= x * x }
            case .geo:
                var p = 1.0
                for _ in 0..<terms { sum += p; p *= x }
            }
            return sum
        }

        var window: (x: ClosedRange<Double>, y: ClosedRange<Double>) {
            switch self {
            case .sin, .cos: return (-2 * Double.pi ... 2 * Double.pi, -2.5...2.5)
            case .exp: return (-3...3, -1...12)
            case .ln: return (-0.95...3, -3...2)
            case .atan: return (-3...3, -2...2)
            case .geo: return (-1.5...1.5, -4...6)
            }
        }

        var radius: String {
            switch self {
            case .sin, .cos, .exp: return "Converges for every x."
            case .ln: return "Radius of convergence 1: it only converges for −1 < x ≤ 1."
            case .atan: return "Radius of convergence 1: it only converges for |x| ≤ 1."
            case .geo: return "Radius of convergence 1: it only converges for |x| < 1."
            }
        }
    }

    @State private var function: Function = .sin
    @State private var terms = 3.0

    var body: some View {
        ExToolPage(info: ["tool.taylor"]) {
            Canvas { ctx, size in draw(&ctx, size) }
        } controls: {
            Picker("Function", selection: $function) {
                ForEach(Function.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            ExParamRow(title: "Terms", value: $terms, range: 1...30, step: 1, format: "%.0f")
            Text(function.radius).font(.footnote).foregroundStyle(.secondary)
            Text("Grey: the function. Colour: its Maclaurin polynomial with the chosen number of non-zero terms.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = function.window
        let box = CGRect(x: 14, y: 80, width: size.width - 28, height: size.height - 120)
        func sx(_ x: Double) -> CGFloat { box.minX + CGFloat((x - w.x.lowerBound) / (w.x.upperBound - w.x.lowerBound)) * box.width }
        func sy(_ y: Double) -> CGFloat { box.maxY - CGFloat((y - w.y.lowerBound) / (w.y.upperBound - w.y.lowerBound)) * box.height }
        ctx.clip(to: Path(box))
        // axes
        var axes = Path()
        axes.move(to: CGPoint(x: box.minX, y: sy(0))); axes.addLine(to: CGPoint(x: box.maxX, y: sy(0)))
        axes.move(to: CGPoint(x: sx(0), y: box.minY)); axes.addLine(to: CGPoint(x: sx(0), y: box.maxY))
        ctx.stroke(axes, with: .color(.secondary.opacity(0.5)), lineWidth: 1)

        func curve(_ f: (Double) -> Double) -> Path {
            var p = Path()
            var pen = false
            let n = 600
            for i in 0...n {
                let x = w.x.lowerBound + (w.x.upperBound - w.x.lowerBound) * Double(i) / Double(n)
                let y = f(x)
                guard y.isFinite, y > w.y.lowerBound - 50, y < w.y.upperBound + 50 else { pen = false; continue }
                let pt = CGPoint(x: sx(x), y: sy(y))
                if pen { p.addLine(to: pt) } else { p.move(to: pt); pen = true }
            }
            return p
        }
        ctx.stroke(curve(function.exact), with: .color(.secondary), lineWidth: 2.5)
        let k = Int(terms)
        ctx.stroke(curve { function.series($0, k) }, with: .color(accent), lineWidth: 2.5)
    }
}

// MARK: - Fourier series (with Gibbs overshoot)

struct FourierSeriesView: View {
    @Environment(\.appAccent) private var accent

    enum Wave: String, CaseIterable, Identifiable {
        case square = "Square", saw = "Sawtooth", triangle = "Triangle"
        var id: String { rawValue }

        func exact(_ x: Double) -> Double {
            let t = x - 2 * .pi * floor((x + .pi) / (2 * .pi))   // wrapped to [-π, π)
            switch self {
            case .square: return t == 0 ? 0 : (t > 0 ? 1 : -1)
            case .saw: return t / .pi
            case .triangle:
                // Rises linearly to 1 at π/2, falls to −1 at −π/2, and is 0 at the origin.
                if abs(t) <= .pi / 2 { return 2 * t / .pi }
                return t > 0 ? 2 * (.pi - t) / .pi : 2 * (-.pi - t) / .pi
            }
        }

        /// Partial sum with `n` non-zero harmonics; optional Lanczos σ-factors suppress the Gibbs ripple.
        func partial(_ x: Double, _ n: Int, lanczos: Bool) -> Double {
            var sum = 0.0
            for j in 1...max(1, n) {
                let order: Int, coefficient: Double
                switch self {
                case .square: order = 2 * j - 1; coefficient = 4 / (.pi * Double(order))
                case .saw: order = j; coefficient = 2 * (j % 2 == 1 ? 1 : -1) / (.pi * Double(order))
                case .triangle:
                    order = 2 * j - 1
                    coefficient = 8 / (.pi * .pi * Double(order * order)) * (j % 2 == 1 ? 1 : -1)
                }
                var sigma = 1.0
                if lanczos {
                    // σ = sinc(order / (highest order + 1))
                    let top = Double((self == .saw ? n : 2 * n - 1) + 1)
                    let a = Double.pi * Double(order) / top
                    sigma = a == 0 ? 1 : sin(a) / a
                }
                sum += coefficient * sigma * sin(Double(order) * x)
            }
            return sum
        }
    }

    @State private var wave: Wave = .square
    @State private var terms = 7.0
    @State private var smooth = false

    private var overshoot: Double {
        guard wave != .triangle else { return 0 }
        let n = Int(terms)
        var best = -Double.infinity
        for i in 1...600 {
            let x = (Double(i) / 600) * (wave == .square ? .pi / 2 : .pi)
            best = max(best, wave.partial(x, n, lanczos: smooth))
        }
        return best - 1
    }

    var body: some View {
        ExToolPage(info: ["tool.fourier", "tool.gibbs"]) {
            Canvas { ctx, size in draw(&ctx, size) }
        } controls: {
            Picker("Wave", selection: $wave) {
                ForEach(Wave.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            ExParamRow(title: "Terms", value: $terms, range: 1...100, step: 1, format: "%.0f")
            Toggle("Smooth with Lanczos σ-factors", isOn: $smooth)
            Text(wave == .triangle
                 ? "A triangle wave is continuous, so its series converges quickly with no overshoot."
                 : String(format: "Peak overshoot: %.3f, i.e. %.1f%% of the jump of 2. However many terms you add it stays near 0.179 (about 8.9%% of the jump): the Gibbs phenomenon. Smoothing greatly reduces it.", overshoot, overshoot / 2 * 100))
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let box = CGRect(x: 14, y: 80, width: size.width - 28, height: size.height - 120)
        let xr = -2 * Double.pi...2 * Double.pi, yr = -1.5...1.5
        func sx(_ x: Double) -> CGFloat { box.minX + CGFloat((x - xr.lowerBound) / (xr.upperBound - xr.lowerBound)) * box.width }
        func sy(_ y: Double) -> CGFloat { box.maxY - CGFloat((y - yr.lowerBound) / (yr.upperBound - yr.lowerBound)) * box.height }
        ctx.clip(to: Path(box))
        var guides = Path()
        for level in [-1.0, 0.0, 1.0] {
            guides.move(to: CGPoint(x: box.minX, y: sy(level))); guides.addLine(to: CGPoint(x: box.maxX, y: sy(level)))
        }
        ctx.stroke(guides, with: .color(.secondary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        if wave != .triangle && overshoot > 0 {
            var line = Path()
            let y = sy(1 + overshoot)
            line.move(to: CGPoint(x: box.minX, y: y)); line.addLine(to: CGPoint(x: box.maxX, y: y))
            ctx.stroke(line, with: .color(.orange.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }
        // exact wave (drawn with vertical jumps)
        var exact = Path()
        var prev: CGPoint?
        let n = 800
        for i in 0...n {
            let x = xr.lowerBound + (xr.upperBound - xr.lowerBound) * Double(i) / Double(n)
            let pt = CGPoint(x: sx(x), y: sy(wave.exact(x)))
            if let p = prev, abs(p.y - pt.y) < box.height * 0.5 { exact.addLine(to: pt) } else { exact.move(to: pt) }
            prev = pt
        }
        ctx.stroke(exact, with: .color(.secondary), lineWidth: 2)
        var approx = Path()
        let m = 1600
        for i in 0...m {
            let x = xr.lowerBound + (xr.upperBound - xr.lowerBound) * Double(i) / Double(m)
            let pt = CGPoint(x: sx(x), y: sy(wave.partial(x, Int(terms), lanczos: smooth)))
            if i == 0 { approx.move(to: pt) } else { approx.addLine(to: pt) }
        }
        ctx.stroke(approx, with: .color(accent), lineWidth: 2.2)
    }
}
