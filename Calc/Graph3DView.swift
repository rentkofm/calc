import SwiftUI

/// Surface plots of `z = f(x, y)`, drawn with a small software renderer so it needs no 3D framework.
struct Graph3DView: View {
    private static let presets: [(name: String, expr: String)] = [
        ("Waves", "sin(x)*cos(y)"),
        ("Ripple", "sin(sqrt(x^2+y^2))"),
        ("Paraboloid", "x^2+y^2"),
        ("Saddle", "x^2-y^2"),
        ("Gaussian", "exp(-(x^2+y^2))"),
        ("Egg Crate", "sin(x)+cos(y)"),
    ]
    private static let ranges: [Double] = [1, 2, 5, 10, 100, 1e3, 1e4, 1e6, 1e9, 1e12]
    private let n = 40

    @State private var text = "sin(x)*cos(y)"
    @State private var yaw = 0.7
    @State private var elevation = 0.6
    /// Half-widths of the x and y domain, and a vertical stretch. Pinching rescales them without limit
    /// (1e-6 … 1e12), so the surface can be followed out toward infinity.
    @State private var xr = 5.0
    @State private var yr = 5.0
    @State private var zStretch = 1.0
    @State private var size = CGSize(width: 320, height: 320)
    @State private var zoomAxis: Axis3?
    @State private var originRanges: (x: Double, y: Double, z: Double)?
    private enum Axis3 { case x, y, z, all }
    @State private var inertia = Inertia()
    @State private var rainbow = true
    @State private var surfaceColor = Color.blue
    @State private var dragOrigin: (yaw: Double, elevation: Double)?
    @Environment(\.graphFullscreen) private var fullscreen
    @FocusState private var focused: Bool

    private var expression: Expr? {
        var s = text.filter { !$0.isWhitespace }
        if s.lowercased().hasPrefix("z=") { s.removeFirst(2) }
        return try? Parser.compile2(s, angle: .radians, allowY: true)
    }

    var body: some View {
        VStack(spacing: 12) {
            surface
            if !fullscreen.wrappedValue {
                if focused { chipRow } else { presetRow }
                inputCard
            }
        }
        .modifier(GraphPage())
    }

    // MARK: Surface

    private var surface: some View {
        Canvas { ctx, size in draw(ctx, size) }
            .frame(minHeight: 240)
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
            .modifier(GraphSurface())
            .overlay(alignment: .topTrailing) {
                if !fullscreen.wrappedValue { EnterFullscreenButton().padding(10) }
            }
            .gesture(
                DragGesture()
                    .onChanged { v in
                        if dragOrigin == nil { inertia.stop(); dragOrigin = (yaw, elevation) }
                        let o = dragOrigin ?? (yaw, elevation)
                        yaw = o.yaw + Double(v.translation.width) * 0.01
                        elevation = min(max(o.elevation + Double(v.translation.height) * 0.008, -.pi / 2), .pi / 2)
                    }
                    .onEnded { v in
                        dragOrigin = nil
                        inertia.start(velocity: v.velocity) { dx, dy in
                            yaw += dx * 0.01
                            elevation = min(max(elevation + dy * 0.008, -.pi / 2), .pi / 2)
                        }
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if originRanges == nil {
                            inertia.stop()
                            originRanges = (xr, yr, zStretch)
                            zoomAxis = axis(at: v.startLocation)
                        }
                        guard let o = originRanges else { return }
                        let m = max(Double(v.magnification), 1e-3)
                        // Pinching out (m > 1) zooms in, i.e. shrinks the domain.
                        if zoomAxis == .x || zoomAxis == .all { xr = min(max(o.x / m, 1e-6), 1e12) }
                        if zoomAxis == .y || zoomAxis == .all { yr = min(max(o.y / m, 1e-6), 1e12) }
                        if zoomAxis == .z { zStretch = min(max(o.z * m, 1e-3), 1e3) }
                    }
                    .onEnded { _ in originRanges = nil; zoomAxis = nil }
            )
    }

    private struct Camera {
        let cx, cy, unit, cosY, sinY, cosE, sinE: Double
        func project(_ X: Double, _ Y: Double, _ Z: Double) -> (point: CGPoint, depth: Double) {
            let x1 = X * cosY - Y * sinY
            let y1 = X * sinY + Y * cosY
            let up = Z * cosE + y1 * sinE
            return (CGPoint(x: cx + x1 * unit, y: cy - up * unit), y1 * cosE - Z * sinE)
        }
    }

    private func camera(_ size: CGSize) -> Camera {
        Camera(cx: Double(size.width) / 2, cy: Double(size.height) / 2,
               unit: Double(min(size.width, size.height)) * 0.38,
               cosY: cos(yaw), sinY: sin(yaw), cosE: cos(elevation), sinE: sin(elevation))
    }

    /// The axis whose drawn line passes under the pinch, or `.all` when it starts away from every axis.
    private func axis(at p: CGPoint) -> Axis3 {
        let cam = camera(size)
        let ends: [(Axis3, (Double, Double, Double))] = [(.x, (1, 0, 0)), (.y, (0, 1, 0)), (.z, (0, 0, 0.9))]
        var best: (axis: Axis3, d: CGFloat)?
        for (ax, e) in ends {
            let a = cam.project(-e.0, -e.1, -e.2).point, b = cam.project(e.0, e.1, e.2).point
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let len2 = ab.x * ab.x + ab.y * ab.y
            guard len2 > 1 else { continue }
            let t = min(max(((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / len2, 0), 1)
            let d = hypot(p.x - (a.x + t * ab.x), p.y - (a.y + t * ab.y))
            if d < 36, d < (best?.d ?? .infinity) { best = (ax, d) }
        }
        return best?.axis ?? .all
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let cam = camera(size)
        func project(_ X: Double, _ Y: Double, _ Z: Double) -> (point: CGPoint, depth: Double) { cam.project(X, Y, Z) }

        // Axes
        let axisColor = GraphicsContext.Shading.color(.secondary.opacity(0.7))
        let axes: [(Axis3, (Double, Double, Double), String)] = [
            (.x, (1, 0, 0), "x ±\(formatNumber(xr, digits: 3))"),
            (.y, (0, 1, 0), "y ±\(formatNumber(yr, digits: 3))"),
            (.z, (0, 0, 0.9), "z"),
        ]
        for (ax, end, label) in axes {
            let a = project(-end.0, -end.1, -end.2).point
            let b = project(end.0, end.1, end.2).point
            var line = Path()
            line.move(to: a); line.addLine(to: b)
            let live = zoomAxis == ax
            ctx.stroke(line, with: live ? .color(.accentColor) : axisColor, lineWidth: live ? 3 : 1)
            ctx.draw(Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary), at: b)
        }

        guard let f = expression else { return }

        // Sample the surface
        let stride = n + 1
        var zs = [Double](repeating: .nan, count: stride * stride)
        for j in 0...n {
            for i in 0...n {
                let x = -xr + 2 * xr * Double(i) / Double(n)
                let y = -yr + 2 * yr * Double(j) / Double(n)
                zs[j * stride + i] = f(x, y)
            }
        }
        let finite = zs.filter(\.isFinite).sorted()
        guard finite.count > 4 else { return }
        // Fit the height to the 2nd–98th percentile so one spike doesn't flatten everything.
        let lo = finite[Int(Double(finite.count - 1) * 0.02)]
        let hi = finite[Int(Double(finite.count - 1) * 0.98)]
        let mid = (lo + hi) / 2, half = max((hi - lo) / 2, 1e-12)

        var baseH: CGFloat = 0, baseS: CGFloat = 0, baseB: CGFloat = 0, baseA: CGFloat = 0
        UIColor(surfaceColor).getHue(&baseH, saturation: &baseS, brightness: &baseB, alpha: &baseA)

        var pts = [(point: CGPoint, depth: Double, h: Double)](repeating: (.zero, 0, .nan), count: zs.count)
        for j in 0...n {
            for i in 0...n {
                let z = zs[j * stride + i]
                guard z.isFinite else { continue }
                let h = min(max((z - mid) / half, -1.5), 1.5)
                let X = -1 + 2 * Double(i) / Double(n)
                let Y = -1 + 2 * Double(j) / Double(n)
                let pr = project(X, Y, h * 0.5 * zStretch)
                pts[j * stride + i] = (pr.point, pr.depth, h)
            }
        }

        // Painter's algorithm: far quads first.
        var quads: [(cell: Int, depth: Double)] = []
        for j in 0..<n {
            for i in 0..<n {
                let c = [j * stride + i, j * stride + i + 1, (j + 1) * stride + i + 1, (j + 1) * stride + i]
                guard c.allSatisfy({ pts[$0].h.isFinite }) else { continue }
                quads.append((j * n + i, c.reduce(0) { $0 + pts[$1].depth } / 4))
            }
        }
        quads.sort { $0.depth > $1.depth }

        for q in quads {
            let i = q.cell % n, j = q.cell / n
            let c = [j * stride + i, j * stride + i + 1, (j + 1) * stride + i + 1, (j + 1) * stride + i]
            var path = Path()
            path.move(to: pts[c[0]].point)
            for k in 1..<4 { path.addLine(to: pts[c[k]].point) }
            path.closeSubpath()
            let h = c.reduce(0) { $0 + pts[$1].h } / 4
            let t = min(max((h + 1) / 2.5, 0), 1)
            let fill = rainbow
                ? Color(hue: 0.66 * (1 - t), saturation: 0.75, brightness: 0.95)
                : Color(hue: Double(baseH), saturation: Double(baseS), brightness: Double(baseB) * (0.5 + 0.5 * t))
            ctx.fill(path, with: .color(fill))
            ctx.stroke(path, with: .color(.black.opacity(0.18)), lineWidth: 0.5)
        }

        ctx.draw(Text("z: \(formatNumber(lo, digits: 4)) … \(formatNumber(hi, digits: 4))")
                    .font(.caption2).foregroundStyle(.secondary),
                 at: CGPoint(x: 14, y: size.height - 12), anchor: .leading)
    }

    // MARK: Input

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Self.presets, id: \.name) { preset in
                        Button {
                            text = preset.expr
                        } label: {
                            Text(preset.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Capsule())
                    }
                }
            }
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(GraphView.chips.filter { $0 != "=" }, id: \.self) { chip in
                        Button {
                            text += chip
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

    private var inputCard: some View {
        HStack(spacing: 10) {
            Text("z =").foregroundStyle(.secondary)
            TextField("f(x, y)", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
            if !text.isEmpty && expression == nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
            Button {
                rainbow.toggle()
            } label: {
                Image(systemName: rainbow ? "rainbow" : "paintbrush.fill")
                    .foregroundStyle(rainbow ? Color.secondary : surfaceColor)
            }
            .buttonStyle(.plain)
            ColorPicker("Surface color", selection: Binding(
                get: { surfaceColor },
                set: { surfaceColor = $0; rainbow = false }
            ), supportsOpacity: false)
            .labelsHidden()
            .fixedSize()
            Menu {
                ForEach(Self.ranges, id: \.self) { r in
                    Button("±\(formatNumber(r))") { xr = r; yr = r; zStretch = 1 }
                }
            } label: {
                Text("±\(formatNumber(max(xr, yr), digits: 3))").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            .accessibilityLabel("Range")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
