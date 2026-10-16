import SwiftUI

typealias V2 = SIMD2<Double>

/// One body's starting state.
struct TBBody: Equatable {
    var m: Double
    var p: V2
    var v: V2
}

/// Three gravitating bodies (G = 1) integrated with RK4 and a step that shrinks during close encounters.
final class ThreeBodySim {
    private struct S {
        var p0, p1, p2, v0, v1, v2: V2
    }

    private(set) var main: [TBBody] = []
    private(set) var twin: [TBBody] = []
    private(set) var trails: [[V2]] = [[], [], []]
    private(set) var twinTrails: [[V2]] = [[], [], []]
    private(set) var time = 0.0
    private(set) var energyDrift = 0.0
    var viewRadius = 3.0
    var lastDate: Date?

    private var m: (Double, Double, Double) = (1, 1, 1)
    private var state = S(p0: .zero, p1: .zero, p2: .zero, v0: .zero, v1: .zero, v2: .zero)
    private var twinState = S(p0: .zero, p1: .zero, p2: .zero, v0: .zero, v1: .zero, v2: .zero)
    private var energy0 = 0.0
    private var trailClock = 0.0
    private static let soft = 1e-3

    func reset(_ bodies: [TBBody], zeroMomentum: Bool) {
        var b = bodies
        if zeroMomentum {
            let M = b.reduce(0) { $0 + $1.m }
            let com = b.reduce(V2.zero) { $0 + $1.p * $1.m } / M
            let mom = b.reduce(V2.zero) { $0 + $1.v * $1.m } / M
            for i in b.indices { b[i].p -= com; b[i].v -= mom }
        }
        m = (b[0].m, b[1].m, b[2].m)
        state = S(p0: b[0].p, p1: b[1].p, p2: b[2].p, v0: b[0].v, v1: b[1].v, v2: b[2].v)
        twinState = state
        twinState.p0.x += 1e-6
        energy0 = energy(state)
        time = 0; energyDrift = 0; trailClock = 0
        trails = [[], [], []]; twinTrails = [[], [], []]
        sync()
        lastDate = nil
        viewRadius = max(1, 1.3 * (b.map { $0.p.x * $0.p.x + $0.p.y * $0.p.y }.max() ?? 1).squareRoot())
    }

    private func sync() {
        main = [TBBody(m: m.0, p: state.p0, v: state.v0), TBBody(m: m.1, p: state.p1, v: state.v1),
                TBBody(m: m.2, p: state.p2, v: state.v2)]
        twin = [TBBody(m: m.0, p: twinState.p0, v: twinState.v0), TBBody(m: m.1, p: twinState.p1, v: twinState.v1),
                TBBody(m: m.2, p: twinState.p2, v: twinState.v2)]
    }

    private func pull(_ a: V2, _ b: V2, _ mb: Double) -> V2 {
        let d = b - a
        let r2 = d.x * d.x + d.y * d.y + Self.soft * Self.soft
        return d * (mb / (r2 * r2.squareRoot()))
    }

    private func accel(_ s: S) -> (V2, V2, V2) {
        (pull(s.p0, s.p1, m.1) + pull(s.p0, s.p2, m.2),
         pull(s.p1, s.p0, m.0) + pull(s.p1, s.p2, m.2),
         pull(s.p2, s.p0, m.0) + pull(s.p2, s.p1, m.1))
    }

    private func deriv(_ s: S) -> S {
        let a = accel(s)
        return S(p0: s.v0, p1: s.v1, p2: s.v2, v0: a.0, v1: a.1, v2: a.2)
    }

    private func adding(_ s: S, _ d: S, _ k: Double) -> S {
        S(p0: s.p0 + d.p0 * k, p1: s.p1 + d.p1 * k, p2: s.p2 + d.p2 * k,
          v0: s.v0 + d.v0 * k, v1: s.v1 + d.v1 * k, v2: s.v2 + d.v2 * k)
    }

    private func rk4(_ s: S, _ dt: Double) -> S {
        let k1 = deriv(s), k2 = deriv(adding(s, k1, dt / 2)), k3 = deriv(adding(s, k2, dt / 2)), k4 = deriv(adding(s, k3, dt))
        func comb(_ a: V2, _ b: V2, _ c: V2, _ d: V2) -> V2 { (a + 2 * b + 2 * c + d) * (dt / 6) }
        return S(p0: s.p0 + comb(k1.p0, k2.p0, k3.p0, k4.p0), p1: s.p1 + comb(k1.p1, k2.p1, k3.p1, k4.p1),
                 p2: s.p2 + comb(k1.p2, k2.p2, k3.p2, k4.p2),
                 v0: s.v0 + comb(k1.v0, k2.v0, k3.v0, k4.v0), v1: s.v1 + comb(k1.v1, k2.v1, k3.v1, k4.v1),
                 v2: s.v2 + comb(k1.v2, k2.v2, k3.v2, k4.v2))
    }

    private func dist(_ a: V2, _ b: V2) -> Double { let d = a - b; return (d.x * d.x + d.y * d.y).squareRoot() }

    private func energy(_ s: S) -> Double {
        func ke(_ mm: Double, _ v: V2) -> Double { 0.5 * mm * (v.x * v.x + v.y * v.y) }
        func pe(_ ma: Double, _ mb: Double, _ a: V2, _ b: V2) -> Double {
            let d = a - b
            return -ma * mb / (d.x * d.x + d.y * d.y + Self.soft * Self.soft).squareRoot()
        }
        return ke(m.0, s.v0) + ke(m.1, s.v1) + ke(m.2, s.v2) + pe(m.0, m.1, s.p0, s.p1) + pe(m.0, m.2, s.p0, s.p2) + pe(m.1, m.2, s.p1, s.p2)
    }

    var totalEnergy: Double { energy(state) }

    /// Step size: a small fraction of the shortest dynamical time among the pairs.
    private func stepSize(_ s: S) -> Double {
        let rmin = min(dist(s.p0, s.p1), min(dist(s.p0, s.p2), dist(s.p1, s.p2)))
        let vmax = max(abs(s.v0.x) + abs(s.v0.y), max(abs(s.v1.x) + abs(s.v1.y), abs(s.v2.x) + abs(s.v2.y)))
        let msum = m.0 + m.1 + m.2
        let tau = min(rmin / max(vmax, 1e-3), (rmin * rmin * rmin / msum).squareRoot())
        return min(0.004, max(2e-5, 0.02 * tau))
    }

    func advance(to date: Date, speed: Double, playing: Bool, trailMax: Int, withTwin: Bool) {
        defer { lastDate = date }
        guard playing, let last = lastDate else { return }
        var remaining = min(date.timeIntervalSince(last), 0.05) * speed
        var guardCount = 0
        while remaining > 1e-9 && guardCount < 12000 {
            let dt = min(remaining, stepSize(state))
            state = rk4(state, dt)
            if withTwin { twinState = rk4(twinState, min(dt, stepSize(twinState))) }
            remaining -= dt
            time += dt
            trailClock += dt
            if trailClock >= 0.012 {
                trailClock = 0
                trails[0].append(state.p0); trails[1].append(state.p1); trails[2].append(state.p2)
                if withTwin { twinTrails[0].append(twinState.p0); twinTrails[1].append(twinState.p1); twinTrails[2].append(twinState.p2) }
                for i in 0..<3 {
                    if trails[i].count > trailMax { trails[i].removeFirst(trails[i].count - trailMax) }
                    if twinTrails[i].count > trailMax { twinTrails[i].removeFirst(twinTrails[i].count - trailMax) }
                }
            }
            guardCount += 1
        }
        energyDrift = abs((energy(state) - energy0) / max(1e-12, abs(energy0)))
        sync()
        // Smoothly zoom to keep every body in view.
        let farthest = main.map { ($0.p.x * $0.p.x + $0.p.y * $0.p.y).squareRoot() }.max() ?? 1
        viewRadius += (max(1, farthest * 1.3) - viewRadius) * 0.05
    }
}

struct TBPreset: Identifiable {
    let name: String
    let note: String
    let bodies: [TBBody]
    let zero: Bool
    var id: String { name }
}

struct ThreeBodyView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent

    private static let presets: [TBPreset] = {
        let lagrangeR = 2 / 3.0.squareRoot(), omega = (3.0 / 8.0).squareRoot()
        let lag = (0..<3).map { i -> TBBody in
            let a = Double.pi / 2 + Double(i) * 2 * .pi / 3
            return TBBody(m: 1, p: V2(lagrangeR * cos(a), lagrangeR * sin(a)),
                          v: V2(-omega * lagrangeR * sin(a), omega * lagrangeR * cos(a)))
        }
        var rng = SplitMix64(state: 7)
        let rnd = (0..<3).map { _ -> TBBody in
            TBBody(m: 0.5 + rng.nextDouble() * 2,
                   p: V2(rng.nextDouble() * 4 - 2, rng.nextDouble() * 4 - 2),
                   v: V2(rng.nextDouble() - 0.5, rng.nextDouble() - 0.5))
        }
        return [
            TBPreset(name: "Figure-eight",
                     note: "Three equal masses chase each other along one figure-eight curve (Chenciner & Montgomery, 2000).",
                     bodies: [TBBody(m: 1, p: V2(-0.97000436, 0.24308753), v: V2(0.466203685, 0.43236573)),
                              TBBody(m: 1, p: V2(0.97000436, -0.24308753), v: V2(0.466203685, 0.43236573)),
                              TBBody(m: 1, p: V2(0, 0), v: V2(-0.93240737, -0.86473146))], zero: false),
            TBPreset(name: "Lagrange triangle",
                     note: "Equal masses at the corners of a rotating equilateral triangle. It is unstable, so it eventually falls apart.",
                     bodies: lag, zero: false),
            TBPreset(name: "Pythagorean",
                     note: "Masses 3, 4, 5 released from rest at the corners of a 3-4-5 triangle: a famously chaotic start.",
                     bodies: [TBBody(m: 3, p: V2(1, 3), v: .zero), TBBody(m: 4, p: V2(-2, -1), v: .zero),
                              TBBody(m: 5, p: V2(1, -1), v: .zero)], zero: true),
            TBPreset(name: "Star, planet, moon",
                     note: "A heavy star, a light planet in a circular orbit and a tiny moon circling the planet.",
                     bodies: [TBBody(m: 10, p: V2(0, 0), v: .zero), TBBody(m: 0.1, p: V2(3, 0), v: V2(0, 1.8257)),
                              TBBody(m: 0.001, p: V2(3.15, 0), v: V2(0, 2.6422))], zero: true),
            TBPreset(name: "Random", note: "Random masses and positions: usually a close encounter and an ejection.",
                     bodies: rnd, zero: true),
        ]
    }()

    @State private var initial: [TBBody] = ThreeBodyView.presets[0].bodies
    @State private var zeroMomentum = false
    @State private var presetName = "Figure-eight"
    @State private var playing = true
    @State private var speed = 1.0
    @State private var trailLength = 700.0
    @State private var showTwin = false
    @State private var sim = ThreeBodySim()

    var body: some View {
        ExToolPage(info: ["tool.threebody"], panelHeight: 270) {
            TimelineView(.animation(paused: !active || !playing)) { tl in
                Canvas { ctx, size in
                    sim.advance(to: tl.date, speed: speed, playing: playing, trailMax: Int(trailLength), withTwin: showTwin)
                    draw(&ctx, size)
                }
            }
        } controls: {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button { playing.toggle() } label: {
                        Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glassProminent)
                    Button { restart() } label: {
                        Label("Restart", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)
                    Menu {
                        ForEach(Self.presets) { p in
                            Button(p.name) { load(p) }
                        }
                    } label: {
                        Label("Presets", systemImage: "list.bullet").frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)
                }
            }
            if let note = Self.presets.first(where: { $0.name == presetName })?.note {
                Text("\(presetName): \(note)").font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ExParamRow(title: "Speed", value: $speed, range: 0.1...6, format: "%.1f×")
            ExParamRow(title: "Trail", value: $trailLength, range: 50...3000, step: 50, format: "%.0f")
            Toggle("Show a twin started 10⁻⁶ away", isOn: $showTwin)
            Toggle("Zero total momentum on restart", isOn: $zeroMomentum)
            ForEach(0..<3, id: \.self) { i in
                DisclosureGroup("Body \(i + 1)") {
                    VStack(spacing: 10) {
                        ExParamRow(title: "mass", value: $initial[i].m, range: 0.001...20, format: "%.3f")
                        ExParamRow(title: "x", value: $initial[i].p.x, range: -6...6, format: "%.3f")
                        ExParamRow(title: "y", value: $initial[i].p.y, range: -6...6, format: "%.3f")
                        ExParamRow(title: "vx", value: $initial[i].v.x, range: -4...4, format: "%.3f")
                        ExParamRow(title: "vy", value: $initial[i].v.y, range: -4...4, format: "%.3f")
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear { restart() }
        .onChange(of: initial) { _, _ in restart() }
        .onChange(of: zeroMomentum) { _, _ in restart() }
    }

    private func load(_ p: TBPreset) {
        presetName = p.name
        zeroMomentum = p.zero
        initial = p.bodies
        restart()
    }

    private func restart() { sim.reset(initial, zeroMomentum: zeroMomentum) }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let mid = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
        let scale = Double(min(size.width * 0.46, size.height * 0.36)) / sim.viewRadius
        func px(_ p: V2) -> CGPoint { CGPoint(x: mid.x + CGFloat(p.x * scale), y: mid.y - CGFloat(p.y * scale)) }
        let colours = (0..<3).map { ExColor.shifted(accent, by: Double($0) * 0.33) }

        func trail(_ pts: [V2], _ color: Color) {
            guard pts.count > 2 else { return }
            let chunks = 12
            let per = max(2, pts.count / chunks + 1)
            var start = 0, i = 0
            while start < pts.count - 1 {
                let end = min(pts.count - 1, start + per)
                var path = Path()
                path.move(to: px(pts[start]))
                for j in (start + 1)...end { path.addLine(to: px(pts[j])) }
                ctx.stroke(path, with: .color(color.opacity(0.1 + 0.9 * Double(end) / Double(pts.count))),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                start = end
                i += 1
            }
        }
        ctx.draw(Text(String(format: "t = %.2f   energy drift %.1e", sim.time, sim.energyDrift))
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.secondary),
                 at: CGPoint(x: 14, y: size.height - 18), anchor: .leading)
        if showTwin { for i in 0..<3 { trail(sim.twinTrails[i], .secondary) } }
        for i in 0..<3 { trail(sim.trails[i], colours[i]) }

        if showTwin {
            for b in sim.twin {
                let c = px(b.p)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)),
                           with: .color(.secondary), lineWidth: 1.2)
            }
        }
        for (i, b) in sim.main.enumerated() {
            let c = px(b.p)
            let r = 5 + 3 * CGFloat(pow(b.m, 1.0 / 3.0))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(colours[i]))
        }
    }
}
