import SwiftUI

/// Primes up to and including `n` (index = number).
func primeSieve(_ n: Int) -> [Bool] {
    var isPrime = [Bool](repeating: true, count: max(2, n + 1))
    isPrime[0] = false; isPrime[1] = false
    var i = 2
    while i * i <= n {
        if isPrime[i] { var j = i * i; while j <= n { isPrime[j] = false; j += i } }
        i += 1
    }
    return isPrime
}

// MARK: - Modular multiplication circle

struct ModularCircleView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent
    @State private var n = 200.0
    @State private var m = 2.0
    @State private var animate = false

    var body: some View {
        ExToolPage(info: ["tool.modular", "tool.cardioid"]) {
            TimelineView(.animation(paused: !active || !animate)) { tl in
                Canvas { ctx, size in
                    let mult = animate ? 2 + (tl.date.timeIntervalSinceReferenceDate * 0.25).truncatingRemainder(dividingBy: 98) : m
                    draw(&ctx, size, mult)
                }
            }
        } controls: {
            ExParamRow(title: "n points", value: $n, range: 10...600, step: 1, format: "%.0f")
            ExParamRow(title: "times m", value: $m, range: 0...100, step: 0.05, format: "%.2f")
                .disabled(animate)
            Toggle("Sweep m from 2 to 100", isOn: $animate)
            Text("Joins point k to point m·k mod n. m = 2 draws a cardioid, m = 3 a nephroid; non-integer m gives continuous families.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ mult: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        let R = min(size.width * 0.46, size.height * 0.38)
        let count = Int(n)
        func pt(_ k: Double) -> CGPoint {
            let a = -Double.pi / 2 + 2 * .pi * k / Double(count)   // point 0 at the top
            return CGPoint(x: c.x + R * cos(a), y: c.y + R * sin(a))
        }
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R)),
                   with: .color(.secondary.opacity(0.35)), lineWidth: 1)
        var lines = Path()
        for k in 0..<count {
            let target = (mult * Double(k)).truncatingRemainder(dividingBy: Double(count))
            lines.move(to: pt(Double(k)))
            lines.addLine(to: pt(target))
        }
        ctx.stroke(lines, with: .color(accent.opacity(count > 300 ? 0.5 : 0.75)), lineWidth: count > 300 ? 0.6 : 0.9)
        if count <= 120 {
            for k in 0..<count {
                let p = pt(Double(k))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(.primary))
            }
        }
        ctx.draw(Text(String(format: "m = %.2f", mult)).font(.caption.monospacedDigit()).foregroundStyle(.secondary),
                 at: CGPoint(x: 50, y: size.height - 20))
    }
}

// MARK: - Ulam and Sacks spirals

struct PrimeSpiralView: View {
    @Environment(\.appAccent) private var accent
    let sacks: Bool
    @State private var count = 12000.0
    @State private var showComposites = false

    /// Coordinates of 1…n on the Ulam square spiral (1 at the origin, 2 to its right, then counter-clockwise).
    private static func ulamPoints(_ n: Int) -> [(Int, Int)] {
        var pts: [(Int, Int)] = [(0, 0), (0, 0)]   // index 0 unused
        var x = 0, y = 0, leg = 1, dir = 0
        let dx = [1, 0, -1, 0], dy = [0, 1, 0, -1]
        var k = 1
        while k < n {
            for _ in 0..<2 {
                for _ in 0..<leg where k < n {
                    x += dx[dir]; y += dy[dir]; k += 1
                    pts.append((x, y))
                }
                dir = (dir + 1) % 4
            }
            leg += 1
        }
        return pts
    }

    var body: some View {
        ExToolPage(info: sacks ? ["tool.sacks", "tool.ulam"] : ["tool.ulam", "tool.sacks"]) {
            Canvas { ctx, size in draw(&ctx, size) }
        } controls: {
            ExParamRow(title: "Numbers", value: $count, range: 200...(sacks ? 20000 : 40000), step: 100, format: "%.0f")
            Toggle("Faintly show composites too", isOn: $showComposites)
            let primes = primeSieve(Int(count)).filter { $0 }.count
            Text(sacks
                 ? "Sacks spiral: n at radius √n and angle 2π√n. Primes line up along curved arms. \(primes) primes ≤ \(Int(count))."
                 : "Ulam spiral: integers wound in a square spiral, primes marked. They cluster on diagonals. \(primes) primes ≤ \(Int(count)).")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let n = Int(count)
        let isPrime = primeSieve(n)
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        let extent = min(size.width * 0.47, size.height * 0.40)
        if sacks {
            let R = Double(n).squareRoot()
            let k = Double(extent) / R
            let dot = max(1.2, min(3.2, 90 / R))
            for i in 1...n {
                if !isPrime[i] && !showComposites { continue }
                let r = Double(i).squareRoot()
                let a = 2 * Double.pi * r
                let p = CGPoint(x: c.x + CGFloat(k * r * cos(a)), y: c.y - CGFloat(k * r * sin(a)))
                let rect = CGRect(x: p.x - CGFloat(dot) / 2, y: p.y - CGFloat(dot) / 2, width: CGFloat(dot), height: CGFloat(dot))
                ctx.fill(Path(ellipseIn: rect), with: .color(isPrime[i] ? accent : .secondary.opacity(0.18)))
            }
        } else {
            let pts = Self.ulamPoints(n)
            let side = Int(Double(n).squareRoot()) + 2
            let cell = max(1, CGFloat(extent * 2) / CGFloat(side))
            for i in 1...n {
                if !isPrime[i] && !showComposites { continue }
                let (x, y) = pts[i]
                let rect = CGRect(x: c.x + CGFloat(x) * cell - cell / 2, y: c.y - CGFloat(y) * cell - cell / 2,
                                  width: max(1, cell * 0.9), height: max(1, cell * 0.9))
                ctx.fill(Path(rect), with: .color(isPrime[i] ? accent : .secondary.opacity(0.15)))
            }
        }
    }
}
