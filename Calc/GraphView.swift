import SwiftUI

struct GraphFunction: Identifiable {
    let id = UUID()
    var text: String
    let colorIndex: Int
}

/// A plottable curve: either `y = f(x)` or an implicit relation `F(x, y) = 0`.
enum Curve {
    case explicit(Expr)
    case implicit(Expr)

    /// Zero exactly on the curve.
    func value(_ x: Double, _ y: Double) -> Double {
        switch self {
        case .explicit(let f): return y - f(x, 0)
        case .implicit(let f): return f(x, y)
        }
    }

    /// Accepts `f(x)`, `y = f(x)`, `f(x) = y`, or any equation like `3x = 2x*2` or `x^2 + y^2 = 25`.
    static func parse(_ raw: String) -> Curve? {
        let parts = raw.split(separator: "=", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        func compile(_ s: String, y: Bool) -> Expr? { try? Parser.compile2(s, angle: .radians, allowY: y) }

        switch parts.count {
        case 1:
            return compile(parts[0], y: false).map(Curve.explicit)
        case 2:
            let (l, r) = (parts[0], parts[1])
            if l.lowercased() == "y", let f = compile(r, y: false) { return .explicit(f) }
            if r.lowercased() == "y", let f = compile(l, y: false) { return .explicit(f) }
            guard let lf = compile(l, y: true), let rf = compile(r, y: true) else { return nil }
            return .implicit({ x, y in lf(x, y) - rf(x, y) })
        default:
            return nil
        }
    }
}

struct SelectedPoint {
    var x: Double
    var y: Double
    var colorIndex: Int
}

struct GraphView: View {
    private typealias Seg = (CGPoint, CGPoint)

    private static let palette: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .red, .indigo]
    static let chips = ["x", "y", "=", "^", "(", ")", "π", "e", "sin(", "cos(", "tan(", "ln(", "log(", "√(", "abs("]

    static func color(for index: Int) -> Color {
        if index < palette.count { return palette[index] }
        let hue = (Double(index) * 0.618033988749895).truncatingRemainder(dividingBy: 1)
        return Color(hue: hue, saturation: 0.65, brightness: 0.9)
    }

    @AppStorage("graphGrid") private var showGrid = true

    @State private var functions = [GraphFunction(text: "sin(x)", colorIndex: 0)]
    @State private var nextColorIndex = 1
    @State private var center = CGPoint.zero
    @State private var scale: CGFloat = 40
    @State private var canvasSize = CGSize(width: 320, height: 320)
    @State private var dragOrigin: CGPoint?
    @State private var scaleOrigin: CGFloat?
    @State private var inertiaTask: Task<Void, Never>?
    @State private var coasting = false
    @State private var selected: SelectedPoint?
    @State private var listContentHeight: CGFloat = 0
    @FocusState private var focused: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                graph
                if focused != nil { chipRow }
                functionList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background { AppBackground() }
            .navigationTitle("Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = nil }
                }
            }
            .onChange(of: functions.map(\.text)) { selected = nil }
            .onDisappear { stopInertia() }
        }
    }

    // MARK: Coordinates

    private func toScreen(_ x: Double, _ y: Double, _ size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + CGFloat(x - Double(center.x)) * scale,
                y: size.height / 2 - CGFloat(y - Double(center.y)) * scale)
    }

    private func toGraph(_ p: CGPoint, _ size: CGSize) -> (x: Double, y: Double) {
        (Double(center.x) + Double(p.x - size.width / 2) / Double(scale),
         Double(center.y) - Double(p.y - size.height / 2) / Double(scale))
    }

    // MARK: Canvas

    private var graph: some View {
        Canvas { ctx, size in draw(ctx, size) }
            .frame(minHeight: 200)
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { canvasSize = $0 })
            .clipShape(.rect(cornerRadius: 28))
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .overlay { selectionOverlay }
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        if dragOrigin == nil { stopInertia(); dragOrigin = center }
                        let o = dragOrigin ?? center
                        center = CGPoint(x: o.x - v.translation.width / scale,
                                         y: o.y + v.translation.height / scale)
                    }
                    .onEnded { v in
                        dragOrigin = nil
                        startInertia(v.velocity)
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if scaleOrigin == nil { stopInertia(); scaleOrigin = scale }
                        scale = min(max((scaleOrigin ?? scale) * v.magnification, 1e-100), 1e100)
                    }
                    .onEnded { _ in scaleOrigin = nil }
            )
            .onTapGesture { location in handleTap(at: location) }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        GeometryReader { geo in
            if let s = selected {
                let p = toScreen(s.x, s.y, geo.size)
                let color = Self.color(for: s.colorIndex)
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .shadow(radius: 2)
                        .position(p)
                    Text("(\(formatNumber(s.x, digits: 5)), \(formatNumber(s.y, digits: 5)))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassEffect(.regular, in: Capsule())
                        .position(x: min(max(p.x, 70), geo.size.width - 70),
                                  y: p.y < 56 ? p.y + 34 : p.y - 34)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Inertia

    private func startInertia(_ velocity: CGSize) {
        stopInertia()
        guard hypot(velocity.width, velocity.height) > 80 else { return }
        coasting = true
        inertiaTask = Task { @MainActor in
            var vx = Double(velocity.width), vy = Double(velocity.height)
            let dt = 1.0 / 60
            let decay = pow(0.05, dt) // retains ~5% of the speed after one second
            while !Task.isCancelled && hypot(vx, vy) > 12 {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                center.x -= CGFloat(vx * dt) / scale
                center.y += CGFloat(vy * dt) / scale
                vx *= decay
                vy *= decay
            }
            coasting = false
        }
    }

    private func stopInertia() {
        inertiaTask?.cancel()
        inertiaTask = nil
        coasting = false
    }

    // MARK: Tap to inspect

    private func handleTap(at p: CGPoint) {
        if coasting { stopInertia(); return } // the first tap just catches the graph
        let size = canvasSize

        var best: (dist: CGFloat, index: Int, point: CGPoint)?
        for (i, fn) in functions.enumerated() {
            guard let curve = Curve.parse(fn.text) else { continue }
            for seg in segments(curve, size) {
                let q = nearest(p, seg.0, seg.1)
                let d = hypot(q.x - p.x, q.y - p.y)
                if d < (best?.dist ?? 32) { best = (d, i, q) }
            }
        }
        guard let hit = best, let curve = Curve.parse(functions[hit.index].text) else {
            selected = nil
            return
        }

        var (gx, gy) = toGraph(hit.point, size)
        if case .explicit(let f) = curve { gy = f(gx, 0) }
        guard gx.isFinite, gy.isFinite else { selected = nil; return }

        // Snap to a whole-number point if the curve passes exactly through one nearby.
        let radius = Double(22 / scale)
        if radius <= 25, abs(gx) < 1e9, abs(gy) < 1e9 {
            var bestDist = Double.infinity
            for nx in Int(floor(gx - radius))...Int(ceil(gx + radius)) {
                for ny in Int(floor(gy - radius))...Int(ceil(gy + radius)) {
                    let v = curve.value(Double(nx), Double(ny))
                    let tolerance = 1e-9 * max(1, abs(Double(nx)), abs(Double(ny)))
                    guard v.isFinite, abs(v) <= tolerance else { continue }
                    let d = hypot(Double(nx) - gx, Double(ny) - gy)
                    if d <= radius, d < bestDist {
                        bestDist = d
                        (gx, gy) = (Double(nx), Double(ny))
                    }
                }
            }
        }
        withAnimation(.snappy(duration: 0.2)) {
            selected = SelectedPoint(x: gx, y: gy, colorIndex: functions[hit.index].colorIndex)
        }
        Haptics.tap()
    }

    private func nearest(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return a }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return CGPoint(x: a.x + t * dx, y: a.y + t * dy)
    }

    // MARK: Curve geometry

    private func segments(_ curve: Curve, _ size: CGSize) -> [Seg] {
        switch curve {
        case .explicit(let f):
            var segs: [Seg] = []
            var prev: CGPoint?
            for i in 0...max(Int(size.width), 1) {
                let x = Double(center.x) + (Double(i) - Double(size.width) / 2) / Double(scale)
                let y = f(x, 0)
                guard y.isFinite else { prev = nil; continue }
                let p = toScreen(x, y, size)
                if abs(p.y) > 1e6 { prev = nil; continue }
                // A huge jump between neighbours is an asymptote, not a line.
                if let pv = prev, abs(p.y - pv.y) < size.height * 2 { segs.append((pv, p)) }
                prev = p
            }
            return segs
        case .implicit(let f):
            return marchingSquares(f, size)
        }
    }

    private func marchingSquares(_ f: Expr, _ size: CGSize) -> [Seg] {
        let step: CGFloat = 6
        let cols = Int(ceil(size.width / step)), rows = Int(ceil(size.height / step))
        guard cols > 0, rows > 0 else { return [] }
        let stride = cols + 1

        var vals = [Double](repeating: .nan, count: stride * (rows + 1))
        for r in 0...rows {
            for c in 0...cols {
                let g = toGraph(CGPoint(x: CGFloat(c) * step, y: CGFloat(r) * step), size)
                vals[r * stride + c] = f(g.x, g.y)
            }
        }

        func t(_ v0: Double, _ v1: Double) -> CGFloat { CGFloat(v0 / (v0 - v1)) }
        var segs: [Seg] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let a = vals[r * stride + c], b = vals[r * stride + c + 1]
                let cc = vals[(r + 1) * stride + c + 1], d = vals[(r + 1) * stride + c]
                guard a.isFinite, b.isFinite, cc.isFinite, d.isFinite else { continue }
                let idx = (a < 0 ? 1 : 0) | (b < 0 ? 2 : 0) | (cc < 0 ? 4 : 0) | (d < 0 ? 8 : 0)
                if idx == 0 || idx == 15 { continue }

                let x0 = CGFloat(c) * step, y0 = CGFloat(r) * step
                let top = CGPoint(x: x0 + step * t(a, b), y: y0)
                let right = CGPoint(x: x0 + step, y: y0 + step * t(b, cc))
                let bottom = CGPoint(x: x0 + step * t(d, cc), y: y0 + step)
                let left = CGPoint(x: x0, y: y0 + step * t(a, d))
                let centerValue = (a + b + cc + d) / 4

                switch idx {
                case 1, 14: segs.append((left, top))
                case 2, 13: segs.append((top, right))
                case 3, 12: segs.append((left, right))
                case 4, 11: segs.append((right, bottom))
                case 6, 9: segs.append((top, bottom))
                case 7, 8: segs.append((left, bottom))
                case 5:
                    if centerValue < 0 { segs.append((top, right)); segs.append((left, bottom)) }
                    else { segs.append((left, top)); segs.append((right, bottom)) }
                case 10:
                    if centerValue < 0 { segs.append((left, top)); segs.append((right, bottom)) }
                    else { segs.append((top, right)); segs.append((left, bottom)) }
                default: break
                }
            }
        }
        return segs
    }

    // MARK: Drawing

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let s = scale
        let step = Self.niceStep(60.0 / Double(s))
        let minX = Double(center.x) - Double(size.width / 2 / s)
        let maxX = Double(center.x) + Double(size.width / 2 / s)
        let minY = Double(center.y) - Double(size.height / 2 / s)
        let maxY = Double(center.y) + Double(size.height / 2 / s)
        let origin = toScreen(0, 0, size)

        let xs = Self.gridValues(minX, maxX, step)
        let ys = Self.gridValues(minY, maxY, step)

        if showGrid {
            var grid = Path()
            for gx in xs {
                let x = toScreen(gx, 0, size).x
                grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for gy in ys {
                let y = toScreen(0, gy, size).y
                grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(grid, with: .color(.secondary.opacity(0.25)), lineWidth: 0.5)
        }

        var axes = Path()
        axes.move(to: CGPoint(x: 0, y: origin.y)); axes.addLine(to: CGPoint(x: size.width, y: origin.y))
        axes.move(to: CGPoint(x: origin.x, y: 0)); axes.addLine(to: CGPoint(x: origin.x, y: size.height))
        ctx.stroke(axes, with: .color(.secondary.opacity(0.8)), lineWidth: 1)

        let labelY = min(max(origin.y + 3, 4), size.height - 16)
        let labelX = min(max(origin.x + 4, 4), size.width - 36)
        for lx in xs where abs(lx) > step / 2 {
            ctx.draw(Text(Self.label(lx)).font(.caption2).foregroundStyle(.secondary),
                     at: CGPoint(x: toScreen(lx, 0, size).x, y: labelY), anchor: .top)
        }
        for ly in ys where abs(ly) > step / 2 {
            ctx.draw(Text(Self.label(ly)).font(.caption2).foregroundStyle(.secondary),
                     at: CGPoint(x: labelX, y: toScreen(0, ly, size).y), anchor: .leading)
        }

        for fn in functions {
            guard let curve = Curve.parse(fn.text) else { continue }
            var path = Path()
            for seg in segments(curve, size) {
                path.move(to: seg.0)
                path.addLine(to: seg.1)
            }
            ctx.stroke(path, with: .color(Self.color(for: fn.colorIndex)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    /// Multiples of `step` inside [lo, hi]; computed by index so it can't stall at extreme zoom.
    private static func gridValues(_ lo: Double, _ hi: Double, _ step: Double) -> [Double] {
        guard step.isFinite, step > 0, lo.isFinite, hi.isFinite else { return [] }
        let first = (lo / step).rounded(.up)
        let count = min(Int(max(0, (hi / step).rounded(.down) - first)) + 1, 200)
        return (0..<count).map { (first + Double($0)) * step }
    }

    private static func niceStep(_ target: Double) -> Double {
        let p = pow(10, floor(log10(target)))
        for m in [1.0, 2.0, 5.0, 10.0] where m * p >= target { return m * p }
        return 10 * p
    }

    private static func label(_ v: Double) -> String {
        formatNumber(abs(v) < 1e-9 ? 0 : v, digits: 6)
    }

    // MARK: Function entry

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Self.chips, id: \.self) { chip in
                        Button {
                            insert(chip)
                        } label: {
                            Text(chip)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .frame(minWidth: 40, minHeight: 36)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Capsule())
                    }
                }
            }
        }
    }

    private func insert(_ s: String) {
        guard let id = focused, let idx = functions.firstIndex(where: { $0.id == id }) else { return }
        functions[idx].text += s
    }

    private var functionList: some View {
        let maxHeight: CGFloat = focused == nil ? 230 : 120
        return ScrollView {
            VStack(spacing: 0) {
                ForEach($functions) { $fn in
                    let valid = fn.text.isEmpty || Curve.parse(fn.text) != nil
                    HStack(spacing: 10) {
                        Circle().fill(Self.color(for: fn.colorIndex)).frame(width: 12, height: 12)
                        TextField("f(x) or equation", text: $fn.text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused, equals: fn.id)
                        if !valid {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        }
                        Button {
                            let id = fn.id
                            withAnimation { functions.removeAll { $0.id == id } }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 10)
                    Divider()
                }
                Button {
                    let new = GraphFunction(text: "", colorIndex: nextColorIndex)
                    nextColorIndex += 1
                    withAnimation { functions.append(new) }
                    focused = new.id
                } label: {
                    Label("Add Function", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 16)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { listContentHeight = $0 })
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(max(listContentHeight, 44), maxHeight))
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
