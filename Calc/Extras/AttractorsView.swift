import SwiftUI

/// Lorenz and Rössler strange attractors: a rotatable 3D trajectory with adjustable parameters,
/// plus a "twin" started 10⁻⁶ away to show sensitive dependence.
struct AttractorsView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent

    enum Kind: String, CaseIterable, Identifiable {
        case lorenz = "Lorenz", rossler = "Rössler"
        var id: String { rawValue }
    }

    @State private var kind: Kind = .lorenz
    @State private var sigma = 10.0
    @State private var rho = 28.0
    @State private var beta = 8.0 / 3.0
    @State private var a = 0.2
    @State private var b = 0.2
    @State private var c = 5.7
    @State private var showTwin = true
    @State private var autoRotate = true
    @State private var yaw = 0.6
    @State private var pitch = 0.35
    @State private var zoom: CGFloat = 1
    @State private var path: [SIMD3<Double>] = []
    @State private var twin: [SIMD3<Double>] = []
    @State private var startDate = Date()
    @State private var dragOrigin: (Double, Double)?
    @State private var zoomOrigin: CGFloat?

    private static let steps = 24000

    private func deriv(_ p: SIMD3<Double>) -> SIMD3<Double> {
        switch kind {
        case .lorenz: return SIMD3(sigma * (p.y - p.x), p.x * (rho - p.z) - p.y, p.x * p.y - beta * p.z)
        case .rossler: return SIMD3(-p.y - p.z, p.x + a * p.y, b + p.z * (p.x - c))
        }
    }

    private func integrate(from start: SIMD3<Double>) -> [SIMD3<Double>] {
        let dt = kind == .lorenz ? 0.005 : 0.012
        var p = start
        var out: [SIMD3<Double>] = []
        out.reserveCapacity(Self.steps)
        for _ in 0..<Self.steps {
            let h: Double = dt / 2
            let k1: SIMD3<Double> = deriv(p)
            let p2: SIMD3<Double> = p + k1 * h
            let k2: SIMD3<Double> = deriv(p2)
            let p3: SIMD3<Double> = p + k2 * h
            let k3: SIMD3<Double> = deriv(p3)
            let p4: SIMD3<Double> = p + k3 * dt
            let k4: SIMD3<Double> = deriv(p4)
            var sum: SIMD3<Double> = k1 + k4
            sum += k2 * 2.0
            sum += k3 * 2.0
            p += sum * (dt / 6)
            out.append(p)
        }
        return out
    }

    private func recompute() {
        let start = SIMD3<Double>(1, 1, kind == .lorenz ? 1 : 0.1)
        path = integrate(from: start)
        twin = integrate(from: start + SIMD3(1e-6, 0, 0))
        startDate = Date()
    }

    /// Centre and radius of the first trajectory, used to fit it on screen.
    private var framing: (centre: SIMD3<Double>, radius: Double) {
        guard !path.isEmpty else { return (.zero, 1) }
        var lo = path[0], hi = path[0]
        for p in path { lo = pointwiseMin(lo, p); hi = pointwiseMax(hi, p) }
        let centre = (lo + hi) / 2
        let r = ((hi - lo) / 2).max()
        guard r.isFinite, r > 1e-6, centre.x.isFinite else { return (.zero, 1) }
        return (centre, r)
    }

    var body: some View {
        ExToolPage(info: ["tool.lorenz", "tool.rossler", "tool.attractor"]) {
            TimelineView(.animation(paused: !active)) { tl in
                Canvas { ctx, size in draw(&ctx, size, tl.date) }
            }
            .gesture(
                DragGesture()
                    .onChanged { v in
                        if dragOrigin == nil { dragOrigin = (yaw, pitch) }
                        let o = dragOrigin ?? (yaw, pitch)
                        yaw = o.0 + Double(v.translation.width) * 0.01
                        pitch = min(max(o.1 + Double(v.translation.height) * 0.01, -1.5), 1.5)
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if zoomOrigin == nil { zoomOrigin = zoom }
                        zoom = min(max((zoomOrigin ?? zoom) * v.magnification, 0.4), 6)
                    }
                    .onEnded { _ in zoomOrigin = nil }
            )
        } controls: {
            Picker("Attractor", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            switch kind {
            case .lorenz:
                ExParamRow(title: "σ", value: $sigma, range: 1...20, format: "%.2f")
                ExParamRow(title: "ρ", value: $rho, range: 0...50, format: "%.2f")
                ExParamRow(title: "β", value: $beta, range: 0.5...5, format: "%.3f")
            case .rossler:
                ExParamRow(title: "a", value: $a, range: 0.05...0.4, format: "%.3f")
                ExParamRow(title: "b", value: $b, range: 0.05...0.4, format: "%.3f")
                ExParamRow(title: "c", value: $c, range: 2...12, format: "%.2f")
            }
            Toggle("Show a twin started 10⁻⁶ away", isOn: $showTwin)
            Toggle("Auto-rotate", isOn: $autoRotate)
            Button { startDate = Date() } label: {
                Label("Replay", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glass)
            Text("Drag to rotate, pinch to zoom. Change a parameter to see the attractor reshape: Lorenz is chaotic near σ=10, ρ=28, β=8/3.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onAppear { if path.isEmpty { recompute() } }
        .onChange(of: kind) { _, _ in recompute() }
        .onChange(of: sigma) { _, _ in recompute() }
        .onChange(of: rho) { _, _ in recompute() }
        .onChange(of: beta) { _, _ in recompute() }
        .onChange(of: a) { _, _ in recompute() }
        .onChange(of: b) { _, _ in recompute() }
        .onChange(of: c) { _, _ in recompute() }
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ date: Date) {
        guard !path.isEmpty else { return }
        // The timeline date can precede `startDate` (set on appear / Replay), so clamp both to stay in range.
        let elapsed = max(0, date.timeIntervalSince(startDate))
        let revealed = max(2, min(path.count, Int(min(elapsed * 5000, 1e7)) + 2))
        let spin = autoRotate ? yaw + elapsed * 0.25 : yaw
        let (cy, sy, cp, sp) = (cos(spin), sin(spin), cos(pitch), sin(pitch))
        let (centre, radius) = framing
        let unit = Double(min(size.width * 0.46, size.height * 0.36)) * Double(zoom) / radius
        let mid = CGPoint(x: size.width / 2, y: size.height / 2 + 24)

        func project(_ p: SIMD3<Double>) -> CGPoint {
            let q = p - centre
            let x1 = q.x * cy - q.y * sy
            let y1 = q.x * sy + q.y * cy
            let up = q.z * cp + y1 * sp
            return CGPoint(x: mid.x + x1 * unit, y: mid.y - up * unit)
        }

        func strokeChunks(_ pts: [SIMD3<Double>], palette: (Double) -> Color, width: CGFloat) {
            let n = min(pts.count, revealed)
            guard n > 2 else { return }
            let chunks = 80
            let per = max(2, n / chunks + 1)
            var start = 0, i = 0
            while start < n - 1 {
                let end = min(n - 1, start + per)
                var p = Path()
                p.move(to: project(pts[start]))
                for j in (start + 1)...end { p.addLine(to: project(pts[j])) }
                ctx.stroke(p, with: .color(palette(Double(start) / Double(pts.count))),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                start = end
                i += 1
            }
        }

        if showTwin {
            strokeChunks(twin, palette: { _ in Color.secondary.opacity(0.55) }, width: 1.2)
        }
        strokeChunks(path, palette: { f in ExColor.shifted(accent, by: 0.5 * f) }, width: 1.6)
        if revealed < path.count, revealed >= 1 {
            let h = project(path[revealed - 1])
            ctx.fill(Path(ellipseIn: CGRect(x: h.x - 4, y: h.y - 4, width: 8, height: 8)), with: .color(accent))
        }
    }
}
