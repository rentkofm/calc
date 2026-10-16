import SwiftUI

struct SelectedPoint {
    var x: Double
    var y: Double
    var rowID: UUID
    var label: String?
}

struct SavedGraph: Identifiable, Codable {
    var id = UUID()
    var name: String
    var date: Date
    var rows: [GraphRow]
    var sliders: [String: GraphSlider]
    var cx: Double
    var cy: Double
    var scale: Double
    var scaleY: Double? = nil
}

private struct PoiKey: Hashable {
    var row: UUID?
    var cx: Double
    var cy: Double
    var scale: Double
    var version: Int
}

struct GraphView: View {
    private typealias Seg = (CGPoint, CGPoint)

    private static let palette: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .red, .indigo]
    static let chips = ["x", "y", "=", "^", "(", ")", "π", "e", "sin(", "cos(", "tan(", "ln(", "log(", "√(", "abs("]
    static let fullChips = ["x", "y", "t", "θ", "r", "=", "<", ">", "≤", "≥", "^", "(", ")", ",", "{", "}", ":",
                            "π", "e", "√(", "abs(", "sin(", "cos(", "tan(", "ln(", "log(", "sum(", "int("]

    static func color(for index: Int) -> Color {
        if index < palette.count { return palette[index] }
        let hue = (Double(index) * 0.618033988749895).truncatingRemainder(dividingBy: 1)
        return Color(hue: hue, saturation: 0.65, brightness: 0.9)
    }

    @AppStorage("graphGrid") private var showGrid = true
    @AppStorage("savedGraphs") private var savedData = Data()

    @State private var rows = [GraphRow(text: "sin(x)", colorHex: GraphView.color(for: 0).hex)]
    @State private var sliders: [String: GraphSlider] = [:]
    @State private var scene = GraphScene()
    @State private var sceneVersion = 0
    @State private var pois: [PointOfInterest] = []
    @State private var nextColorIndex = 1

    @State private var center = CGPoint.zero
    @State private var scale: CGFloat = 40
    /// Vertical pixels per unit. Equal to `scale` until the user pinches along one axis.
    @State private var scaleY: CGFloat = 40
    @State private var scaleYOrigin: CGFloat?
    @State private var zoomAxis: ZoomAxis?
    @State private var canvasSize = CGSize(width: 320, height: 320)
    @State private var dragOrigin: CGPoint?
    @State private var scaleOrigin: CGFloat?
    private enum ZoomAxis { case x, y, both }
    @State private var inertiaTask: Task<Void, Never>?
    @State private var coasting = false
    @State private var selected: SelectedPoint?

    @State private var panelHidden = false
    @State private var listContentHeight: CGFloat = 0
    @State private var animating: Set<String> = []
    @State private var directions: [String: Double] = [:]
    @State private var animationTask: Task<Void, Never>?

    @State private var currentSavedID: UUID?
    @State private var showSaved = false
    @State private var showNameAlert = false
    @State private var saveName = ""
    @Environment(\.graphFullscreen) private var fullscreen
    @FocusState private var focused: UUID?

    var body: some View {
        VStack(spacing: 10) {
            graph
            if !panelHidden && !fullscreen.wrappedValue {
                if focused != nil { chipRow }
                panel
            }
        }
        .modifier(GraphPage())
        .onAppear { recompile() }
        .onChange(of: rows) { recompile() }
        .onChange(of: sliders) { recompile() }
        .onChange(of: rows.map(\.text)) { selected = nil }
        .onDisappear { stopInertia() }
        .task(id: poiKey) { await refreshPOIs() }
        .alert("Save Graph", isPresented: $showNameAlert) {
            TextField("Name", text: $saveName)
            Button("Save") { saveCurrent(named: saveName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves your expressions, sliders and view.")
        }
        .sheet(isPresented: $showSaved) {
            SavedGraphsSheet(graphs: savedGraphs, onLoad: { load($0) }, onDelete: { deleteSaved($0) })
        }
    }

    // MARK: Compilation

    private func recompile() {
        let new = GraphEngine.compile(rows: rows, sliders: sliders)
        for name in new.freeLetters where sliders[name] == nil { sliders[name] = GraphSlider() }
        scene = new
        sceneVersion += 1
    }

    // MARK: Saved graphs

    private var savedGraphs: [SavedGraph] {
        (try? JSONDecoder().decode([SavedGraph].self, from: savedData)) ?? []
    }

    private func writeSaved(_ list: [SavedGraph]) {
        savedData = (try? JSONEncoder().encode(list)) ?? Data()
    }

    private func saveCurrent(named name: String?) {
        var list = savedGraphs
        var existing: Int?
        if name == nil, let current = currentSavedID {
            existing = list.firstIndex { $0.id == current }
        }
        var title = name?.trimmingCharacters(in: .whitespaces) ?? ""
        if title.isEmpty { title = existing.map { list[$0].name } ?? "Graph \(list.count + 1)" }
        let snapshot = SavedGraph(id: existing.map { list[$0].id } ?? UUID(), name: title, date: Date(),
                                  rows: rows, sliders: sliders, cx: Double(center.x), cy: Double(center.y),
                                  scale: Double(scale), scaleY: Double(scaleY))
        if let idx = existing { list[idx] = snapshot } else { list.insert(snapshot, at: 0) }
        currentSavedID = snapshot.id
        writeSaved(list)
        Haptics.tap()
    }

    private func load(_ g: SavedGraph) {
        stopInertia()
        rows = g.rows
        sliders = g.sliders
        center = CGPoint(x: g.cx, y: g.cy)
        scale = CGFloat(g.scale)
        scaleY = CGFloat(g.scaleY ?? g.scale)
        currentSavedID = g.id
        selected = nil
        showSaved = false
    }

    private func deleteSaved(_ id: UUID) {
        writeSaved(savedGraphs.filter { $0.id != id })
        if currentSavedID == id { currentSavedID = nil }
    }

    // MARK: Coordinates

    private func toScreen(_ x: Double, _ y: Double, _ size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + CGFloat(x - Double(center.x)) * scale,
                y: size.height / 2 - CGFloat(y - Double(center.y)) * scaleY)
    }

    private func toGraph(_ p: CGPoint, _ size: CGSize) -> (x: Double, y: Double) {
        (Double(center.x) + Double(p.x - size.width / 2) / Double(scale),
         Double(center.y) - Double(p.y - size.height / 2) / Double(scaleY))
    }

    // MARK: Canvas

    private var graph: some View {
        Canvas { ctx, size in draw(ctx, size) }
            .frame(minHeight: 200)
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { canvasSize = $0 })
            .modifier(GraphSurface())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        if dragOrigin == nil { stopInertia(); dragOrigin = center }
                        let o = dragOrigin ?? center
                        center = CGPoint(x: o.x - v.translation.width / scale,
                                         y: o.y + v.translation.height / scaleY)
                    }
                    .onEnded { v in
                        dragOrigin = nil
                        startInertia(v.velocity)
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if scaleOrigin == nil {
                            stopInertia()
                            scaleOrigin = scale
                            scaleYOrigin = scaleY
                            zoomAxis = axis(at: v.startLocation)
                        }
                        let m = v.magnification
                        let (sx, sy) = (scaleOrigin ?? scale, scaleYOrigin ?? scaleY)
                        if zoomAxis != .y { scale = min(max(sx * m, 1e-100), 1e100) }
                        if zoomAxis != .x { scaleY = min(max(sy * m, 1e-100), 1e100) }
                    }
                    .onEnded { _ in scaleOrigin = nil; scaleYOrigin = nil; zoomAxis = nil }
            )
            .onTapGesture { location in handleTap(at: location) }
            .overlay { selectionOverlay }
            .overlay(alignment: .topLeading) {
                if !fullscreen.wrappedValue { leadingControls.padding(10) }
            }
            .overlay(alignment: .topTrailing) {
                if !fullscreen.wrappedValue { trailingControls.padding(10) }
            }
    }

    /// A pinch that starts on an axis line stretches only that axis; anywhere else zooms both.
    private func axis(at p: CGPoint) -> ZoomAxis {
        let o = toScreen(0, 0, canvasSize)
        let reach: CGFloat = 36
        let nearX = abs(p.y - o.y) < reach   // on the horizontal (x) axis
        let nearY = abs(p.x - o.x) < reach   // on the vertical (y) axis
        if nearX && !nearY { return .x }
        if nearY && !nearX { return .y }
        return .both
    }

    private var leadingControls: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Button("Save as New…", systemImage: "plus") {
                        saveName = "Graph \(savedGraphs.count + 1)"
                        showNameAlert = true
                    }
                    if let id = currentSavedID, let g = savedGraphs.first(where: { $0.id == id }) {
                        Button("Update “\(g.name)”", systemImage: "arrow.triangle.2.circlepath") { saveCurrent(named: nil) }
                    }
                } label: {
                    Image(systemName: currentSavedID == nil ? "bookmark" : "bookmark.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Save graph")

                Button {
                    showSaved = true
                } label: {
                    Image(systemName: "tray.full")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Saved graphs")
            }
        }
    }

    private var trailingControls: some View {
        HStack(spacing: 8) {
            EnterFullscreenButton()
        }
    }

    private var panelToggle: some View {
        Button {
            withAnimation(.smooth) { panelHidden.toggle() }
            focused = nil
        } label: {
            Image(systemName: panelHidden ? "list.bullet" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(panelHidden ? "Show expressions" : "Expand graph")
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        GeometryReader { geo in
            // Hide the marker (and its label) whenever the point is panned or zoomed off the graph.
            if let s = selected, case let p = toScreen(s.x, s.y, geo.size),
               CGRect(origin: .zero, size: geo.size).contains(p) {
                let color = scene.drawables.first { $0.rowID == s.rowID }?.color ?? .accentColor
                let coords = "(\(formatNumber(s.x, digits: 5)), \(formatNumber(s.y, digits: 5)))"
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .shadow(radius: 2)
                        .position(p)
                    Text(s.label.map { "\($0)  \(coords)" } ?? coords)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassEffect(.regular, in: Capsule())
                        .position(x: min(max(p.x, 90), geo.size.width - 90),
                                  y: p.y < 56 ? p.y + 34 : p.y - 34)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 28))
        .allowsHitTesting(false)
    }

    // MARK: Points of interest

    private var poiKey: PoiKey {
        PoiKey(row: selected?.rowID, cx: Double(center.x), cy: Double(center.y), scale: Double(scale), version: sceneVersion)
    }

    @MainActor
    private func refreshPOIs() async {
        guard let rowID = selected?.rowID else {
            if !pois.isEmpty { pois = [] }
            return
        }
        try? await Task.sleep(for: .milliseconds(150)) // wait until panning and zooming settle
        if Task.isCancelled { return }
        guard let f = scene.drawables.first(where: { $0.rowID == rowID && $0.explicit != nil })?.explicit else {
            pois = []
            return
        }
        let others = scene.drawables.filter { $0.rowID != rowID }.compactMap(\.explicit)
        let half = Double(canvasSize.width / 2 / scale)
        pois = GraphEngine.pointsOfInterest(of: f, others: others,
                                            lo: Double(center.x) - half, hi: Double(center.x) + half)
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
                center.y += CGFloat(vy * dt) / scaleY
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

        // Points of interest on the selected curve come first.
        if let rowID = selected?.rowID {
            var nearestPOI: (dist: CGFloat, poi: PointOfInterest)?
            for poi in pois {
                let s = toScreen(poi.x, poi.y, size)
                let d = hypot(s.x - p.x, s.y - p.y)
                if d < 24, d < (nearestPOI?.dist ?? .infinity) { nearestPOI = (d, poi) }
            }
            if let hit = nearestPOI {
                withAnimation(.snappy(duration: 0.2)) {
                    selected = SelectedPoint(x: hit.poi.x, y: hit.poi.y, rowID: rowID, label: hit.poi.kind)
                }
                Haptics.tap()
                return
            }
        }

        var best: (dist: CGFloat, drawable: Drawable, point: CGPoint, exact: (Double, Double)?)?
        for d in scene.drawables {
            if case .points(let pts) = d.shape {
                for q in pts {
                    let s = toScreen(q.x, q.y, size)
                    let dist = hypot(s.x - p.x, s.y - p.y)
                    if dist < (best?.dist ?? 32) { best = (dist, d, s, (q.x, q.y)) }
                }
                continue
            }
            for seg in segments(d, size) {
                let q = nearest(p, seg.0, seg.1)
                let dist = hypot(q.x - p.x, q.y - p.y)
                if dist < (best?.dist ?? 32) { best = (dist, d, q, nil) }
            }
        }
        guard let hit = best else {
            selected = nil
            return
        }

        var gx: Double, gy: Double
        if let e = hit.exact {
            (gx, gy) = e
        } else {
            let g = toGraph(hit.point, size)
            (gx, gy) = (g.x, g.y)
        }
        if hit.exact == nil, case .curve(let curve) = hit.drawable.shape {
            if case .explicit(let f) = curve { gy = f(gx, 0) }
            guard gx.isFinite, gy.isFinite else { selected = nil; return }

            // Snap to a whole-number point if the curve passes exactly through one nearby.
            let radius = Double(22 / min(scale, scaleY))
            if radius <= 25, abs(gx) < 1e9, abs(gy) < 1e9 {
                var bestDist = Double.infinity
                for nx in Int(floor(gx - radius))...Int(ceil(gx + radius)) {
                    for ny in Int(floor(gy - radius))...Int(ceil(gy + radius)) {
                        let v = curve.value(Double(nx), Double(ny))
                        let tolerance = 1e-9 * max(1, abs(Double(nx)), abs(Double(ny)))
                        guard v.isFinite, abs(v) <= tolerance else { continue }
                        let dist = hypot(Double(nx) - gx, Double(ny) - gy)
                        if dist <= radius, dist < bestDist {
                            bestDist = dist
                            (gx, gy) = (Double(nx), Double(ny))
                        }
                    }
                }
            }
        }
        guard gx.isFinite, gy.isFinite else { selected = nil; return }
        withAnimation(.snappy(duration: 0.2)) {
            selected = SelectedPoint(x: gx, y: gy, rowID: hit.drawable.rowID, label: nil)
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

    private func segments(_ d: Drawable, _ size: CGSize) -> [Seg] {
        switch d.shape {
        case .curve(let curve):
            return segments(curve, size)
        case .inequality(let ineq):
            return ineq.boundaries.flatMap { segments($0.curve, size) }
        case .parametric(let fx, let fy, let lo, let hi):
            return sampled(lo, hi, size) { t in (fx(0, t), fy(0, t)) }
        case .polar(let r, let lo, let hi):
            return sampled(lo, hi, size) { t in
                let radius = r(0, t)
                return (radius * cos(t), radius * sin(t))
            }
        case .points:
            return []
        }
    }

    private func sampled(_ lo: Double, _ hi: Double, _ size: CGSize, _ point: (Double) -> (Double, Double)) -> [Seg] {
        guard lo.isFinite, hi.isFinite, hi > lo else { return [] }
        let count = min(max(Int((hi - lo) * 120), 400), 8000)
        var segs: [Seg] = []
        var prev: CGPoint?
        let limit = max(size.width, size.height) * 1.5
        for i in 0...count {
            let t = lo + (hi - lo) * Double(i) / Double(count)
            let (x, y) = point(t)
            guard x.isFinite, y.isFinite else { prev = nil; continue }
            let p = toScreen(x, y, size)
            if abs(p.x) > 1e6 || abs(p.y) > 1e6 { prev = nil; continue }
            if let pv = prev, hypot(p.x - pv.x, p.y - pv.y) < limit { segs.append((pv, p)) }
            prev = p
        }
        return segs
    }

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
        let stepX = Self.niceStep(60.0 / Double(scale))
        let stepY = Self.niceStep(60.0 / Double(scaleY))
        let minX = Double(center.x) - Double(size.width / 2 / scale)
        let maxX = Double(center.x) + Double(size.width / 2 / scale)
        let minY = Double(center.y) - Double(size.height / 2 / scaleY)
        let maxY = Double(center.y) + Double(size.height / 2 / scaleY)
        let origin = toScreen(0, 0, size)

        let xs = Self.gridValues(minX, maxX, stepX)
        let ys = Self.gridValues(minY, maxY, stepY)

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

        var hAxis = Path(), vAxis = Path()
        hAxis.move(to: CGPoint(x: 0, y: origin.y)); hAxis.addLine(to: CGPoint(x: size.width, y: origin.y))
        vAxis.move(to: CGPoint(x: origin.x, y: 0)); vAxis.addLine(to: CGPoint(x: origin.x, y: size.height))
        let live = Color.accentColor
        ctx.stroke(hAxis, with: zoomAxis == .x ? .color(live) : .color(.secondary.opacity(0.8)), lineWidth: zoomAxis == .x ? 3 : 1)
        ctx.stroke(vAxis, with: zoomAxis == .y ? .color(live) : .color(.secondary.opacity(0.8)), lineWidth: zoomAxis == .y ? 3 : 1)

        let labelY = min(max(origin.y + 3, 4), size.height - 16)
        let labelX = min(max(origin.x + 4, 4), size.width - 36)
        for lx in xs where abs(lx) > stepX / 2 {
            ctx.draw(Text(Self.label(lx)).font(.caption2).foregroundStyle(.secondary),
                     at: CGPoint(x: toScreen(lx, 0, size).x, y: labelY), anchor: .top)
        }
        for ly in ys where abs(ly) > stepY / 2 {
            ctx.draw(Text(Self.label(ly)).font(.caption2).foregroundStyle(.secondary),
                     at: CGPoint(x: labelX, y: toScreen(0, ly, size).y), anchor: .leading)
        }

        // Shaded regions first so lines sit on top.
        for d in scene.drawables {
            if case .inequality(let ineq) = d.shape { fill(ineq, color: d.color, ctx, size) }
        }

        let solid = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        for d in scene.drawables {
            switch d.shape {
            case .curve, .parametric, .polar:
                ctx.stroke(path(for: segments(d, size)), with: .color(d.color), style: solid)
            case .inequality(let ineq):
                for boundary in ineq.boundaries {
                    let style = boundary.dashed
                        ? StrokeStyle(lineWidth: 2.5, lineCap: .butt, lineJoin: .round, dash: [8, 6])
                        : solid
                    ctx.stroke(path(for: segments(boundary.curve, size)), with: .color(d.color), style: style)
                }
            case .points(let pts):
                for q in pts {
                    let c = toScreen(q.x, q.y, size)
                    guard c.x.isFinite, c.y.isFinite, abs(c.x) < 1e5, abs(c.y) < 1e5 else { continue }
                    let dot = Path(ellipseIn: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10))
                    ctx.fill(dot, with: .color(d.color))
                    ctx.stroke(dot, with: .color(.white), lineWidth: 2)
                }
            }
        }

        // Points of interest for the selected curve.
        let poiColor = selected.flatMap { sel in scene.drawables.first { $0.rowID == sel.rowID }?.color } ?? .accentColor
        for poi in pois {
            let c = toScreen(poi.x, poi.y, size)
            guard CGRect(origin: .zero, size: size).contains(c) else { continue }
            let dot = Path(ellipseIn: CGRect(x: c.x - 5.5, y: c.y - 5.5, width: 11, height: 11))
            ctx.fill(dot, with: .color(.white))
            ctx.stroke(dot, with: .color(poiColor), lineWidth: 2.5)
        }
    }

    private func path(for segs: [Seg]) -> Path {
        var path = Path()
        for seg in segs {
            path.move(to: seg.0)
            path.addLine(to: seg.1)
        }
        return path
    }

    private func fill(_ ineq: Inequality, color: Color, _ ctx: GraphicsContext, _ size: CGSize) {
        let cell: CGFloat = 5
        let cols = Int(ceil(size.width / cell)), rowCount = Int(ceil(size.height / cell))
        guard cols > 0, rowCount > 0 else { return }
        var region = Path()
        for r in 0..<rowCount {
            var runStart: Int?
            let py = (CGFloat(r) + 0.5) * cell
            for c in 0...cols {
                var inside = false
                if c < cols {
                    let g = toGraph(CGPoint(x: (CGFloat(c) + 0.5) * cell, y: py), size)
                    inside = ineq.holds(g.x, g.y) != 0
                }
                if inside {
                    if runStart == nil { runStart = c }
                } else if let start = runStart {
                    region.addRect(CGRect(x: CGFloat(start) * cell, y: CGFloat(r) * cell,
                                          width: CGFloat(c - start) * cell, height: cell))
                    runStart = nil
                }
            }
        }
        ctx.fill(region, with: .color(color.opacity(0.26)))
    }

    /// Multiples of `step` inside [lo, hi]; computed by index so it can't stall at extreme zoom.
    static func gridValues(_ lo: Double, _ hi: Double, _ step: Double) -> [Double] {
        guard step.isFinite, step > 0, lo.isFinite, hi.isFinite else { return [] }
        let first = (lo / step).rounded(.up)
        let count = min(Int(max(0, (hi / step).rounded(.down) - first)) + 1, 200)
        return (0..<count).map { (first + Double($0)) * step }
    }

    static func niceStep(_ target: Double) -> Double {
        let p = pow(10, floor(log10(target)))
        for m in [1.0, 2.0, 5.0, 10.0] where m * p >= target { return m * p }
        return 10 * p
    }

    private static func label(_ v: Double) -> String {
        formatNumber(abs(v) < 1e-9 ? 0 : v, digits: 6)
    }

    // MARK: Entry panel

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Self.fullChips, id: \.self) { chip in
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
        guard let id = focused, let idx = rows.firstIndex(where: { $0.id == id }), rows[idx].kind == .expression else { return }
        rows[idx].text += s
    }

    private var panel: some View {
        let maxHeight: CGFloat = focused == nil ? 330 : 150
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(scene.freeLetters, id: \.self) { name in
                    SliderRow(name: name,
                              spec: Binding(get: { sliders[name] ?? GraphSlider() }, set: { sliders[name] = $0 }),
                              playing: animating.contains(name),
                              onPlay: { toggleAnimation(name) })
                    Divider()
                }
                ForEach($rows) { $row in
                    GraphRowView(row: $row,
                                 status: scene.statuses[row.id] ?? .empty,
                                 focus: $focused,
                                 onDuplicate: { duplicate(row) },
                                 onDelete: { delete(row.id) })
                    Divider()
                }
                Menu {
                    Button("Expression", systemImage: "function") { addRow(.expression) }
                    Button("Table", systemImage: "tablecells") { addRow(.table) }
                    Button("Slider", systemImage: "slider.horizontal.3") { addSliderRow() }
                } label: {
                    Label("Add", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
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

    private func newColorHex() -> String {
        defer { nextColorIndex += 1 }
        return Self.color(for: nextColorIndex).hex
    }

    private func addRow(_ kind: GraphRow.Kind) {
        let row = GraphRow(kind: kind, colorHex: newColorHex())
        withAnimation { rows.append(row) }
        focused = row.id
    }

    private func addSliderRow() {
        let used = Set(scene.freeLetters)
        let name = "abcdfghjkmnpqstuvwz".map(String.init).first { n in
            !used.contains(n) && !rows.contains { $0.text.hasPrefix(n) }
        } ?? "a"
        withAnimation { rows.append(GraphRow(text: "\(name) = 1", colorHex: newColorHex())) }
    }

    private func duplicate(_ row: GraphRow) {
        var copy = row
        copy.id = UUID()
        copy.colorHex = newColorHex()
        if let idx = rows.firstIndex(where: { $0.id == row.id }) {
            withAnimation { rows.insert(copy, at: idx + 1) }
        }
    }

    private func delete(_ id: UUID) {
        withAnimation { rows.removeAll { $0.id == id } }
    }

    private func toggleAnimation(_ name: String) {
        if animating.contains(name) { animating.remove(name) } else { animating.insert(name); directions[name] = 1 }
        if animating.isEmpty {
            animationTask?.cancel()
            animationTask = nil
            return
        }
        guard animationTask == nil else { return }
        animationTask = Task { @MainActor in
            while !Task.isCancelled && !animating.isEmpty {
                try? await Task.sleep(for: .milliseconds(33))
                for name in animating {
                    guard var spec = sliders[name], spec.hi > spec.lo else { continue }
                    let direction = directions[name] ?? 1
                    spec.value += direction * (spec.hi - spec.lo) / 180
                    if spec.value >= spec.hi { spec.value = spec.hi; directions[name] = -1 }
                    if spec.value <= spec.lo { spec.value = spec.lo; directions[name] = 1 }
                    sliders[name] = spec
                }
            }
            animationTask = nil
        }
    }
}

// MARK: Rows

private func sliderText(_ v: Double) -> String {
    String(format: "%g", (v * 1000).rounded() / 1000)
}

private struct RangeMenu: View {
    @Binding var lo: Double
    @Binding var hi: Double

    private static let presets: [(String, Double, Double)] = [
        ("−1 … 1", -1, 1), ("0 … 1", 0, 1), ("−10 … 10", -10, 10), ("0 … 10", 0, 10),
        ("−100 … 100", -100, 100), ("−π … π", -Double.pi, Double.pi), ("0 … 2π", 0, 2 * Double.pi),
    ]

    var body: some View {
        Menu {
            ForEach(Self.presets, id: \.0) { preset in
                Button(preset.0) { lo = preset.1; hi = preset.2 }
            }
        } label: {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
    }
}

private struct SliderRow: View {
    let name: String
    @Binding var spec: GraphSlider
    var playing: Bool
    var onPlay: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .italic()
                .frame(width: 22)
            Slider(value: Binding(
                get: { min(max(spec.value, spec.lo), spec.hi) },
                set: { spec.value = (($0 * 1000).rounded() / 1000) }
            ), in: spec.lo...max(spec.hi, spec.lo + 0.001))
            Text(sliderText(spec.value))
                .font(.system(size: 13, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 40, alignment: .trailing)
            RangeMenu(lo: $spec.lo, hi: $spec.hi)
            Button(action: onPlay) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

private struct GraphRowView: View {
    @Binding var row: GraphRow
    var status: LineStatus
    var focus: FocusState<UUID?>.Binding
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ColorPicker("Line color", selection: $row.color, supportsOpacity: false)
                    .labelsHidden()
                    .fixedSize()
                    .opacity(row.visible ? 1 : 0.4)
                if row.kind == .expression {
                    TextField("Expression, equation or inequality", text: $row.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused(focus, equals: row.id)
                        .foregroundStyle(row.visible ? .primary : .secondary)
                } else {
                    Label("Table", systemImage: "tablecells")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Fit", selection: $row.fit) {
                        ForEach(RegressionModel.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                if case .error = status {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                Menu {
                    Button(row.visible ? "Hide" : "Show", systemImage: row.visible ? "eye.slash" : "eye") {
                        row.visible.toggle()
                    }
                    Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }

            if row.kind == .table {
                TextEditor(text: $row.text)
                    .font(.system(size: 15, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96, maxHeight: 140)
                    .padding(6)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    .focused(focus, equals: row.id)
                    .overlay(alignment: .topLeading) {
                        if row.text.isEmpty {
                            Text("x, y — one point per line")
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }
            }

            statusView
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .variable(let name, let value):
            HStack(spacing: 8) {
                Slider(value: Binding(
                    get: { value },
                    set: { row.text = "\(name) = \(sliderText($0))" }
                ), in: min(row.lo, value)...max(row.hi, value, min(row.lo, value) + 0.001))
                Text(sliderText(value))
                    .font(.system(size: 13, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)
                RangeMenu(lo: $row.lo, hi: $row.hi)
            }
        case .value(let text):
            Text(text).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
        case .note(let text):
            Text(text).font(.footnote).foregroundStyle(.secondary)
        case .error(let message):
            Text(message).font(.footnote).foregroundStyle(.red)
        case .empty, .ok:
            EmptyView()
        }
    }
}

// MARK: Saved graphs

private struct SavedGraphsSheet: View {
    var graphs: [SavedGraph]
    var onLoad: (SavedGraph) -> Void
    var onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if graphs.isEmpty {
                    ContentUnavailableView("No Saved Graphs", systemImage: "bookmark",
                                           description: Text("Tap the bookmark on the graph to save one."))
                } else {
                    List {
                        ForEach(graphs) { g in
                            Button {
                                onLoad(g)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(g.name).foregroundStyle(.primary)
                                    Text("\(g.rows.count) lines · \(g.date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in offsets.map { graphs[$0].id }.forEach(onDelete) }
                    }
                }
            }
            .navigationTitle("Saved Graphs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
