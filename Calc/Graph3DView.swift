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
    private static let ranges: [Double] = [1, 2, 5, 10, 20, 50, 100]
    private let n = 40

    @State private var text = "sin(x)*cos(y)"
    @State private var yaw = 0.7
    @State private var elevation = 0.6
    @State private var zoom: CGFloat = 1
    @State private var range = 5.0
    @State private var rainbow = true
    @State private var surfaceColor = Color.blue
    @State private var dragOrigin: (yaw: Double, elevation: Double)?
    @State private var zoomOrigin: CGFloat?
    @FocusState private var focused: Bool

    private var expression: Expr? {
        var s = text.filter { !$0.isWhitespace }
        if s.lowercased().hasPrefix("z=") { s.removeFirst(2) }
        return try? Parser.compile2(s, angle: .radians, allowY: true)
    }

    var body: some View {
        VStack(spacing: 12) {
            surface
            if focused { chipRow } else { presetRow }
            inputCard
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    // MARK: Surface

    private var surface: some View {
        Canvas { ctx, size in draw(ctx, size) }
            .frame(minHeight: 240)
            .clipShape(.rect(cornerRadius: 28))
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .gesture(
                DragGesture()
                    .onChanged { v in
                        if dragOrigin == nil { dragOrigin = (yaw, elevation) }
                        let o = dragOrigin ?? (yaw, elevation)
                        yaw = o.yaw + Double(v.translation.width) * 0.01
                        elevation = min(max(o.elevation + Double(v.translation.height) * 0.008, -.pi / 2), .pi / 2)
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if zoomOrigin == nil { zoomOrigin = zoom }
                        zoom = min(max((zoomOrigin ?? zoom) * v.magnification, 0.2), 20)
                    }
                    .onEnded { _ in zoomOrigin = nil }
            )
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let unit = Double(min(size.width, size.height)) * 0.38 * Double(zoom)
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        let (cosY, sinY, cosE, sinE) = (cos(yaw), sin(yaw), cos(elevation), sin(elevation))

        // Orthographic camera: yaw about the vertical axis, then tilt by `elevation`.
        func project(_ X: Double, _ Y: Double, _ Z: Double) -> (point: CGPoint, depth: Double) {
            let x1 = X * cosY - Y * sinY
            let y1 = X * sinY + Y * cosY
            let up = Z * cosE + y1 * sinE
            return (CGPoint(x: cx + x1 * unit, y: cy - up * unit), y1 * cosE - Z * sinE)
        }

        // Axes
        let axisColor = GraphicsContext.Shading.color(.secondary.opacity(0.7))
        for (end, label) in [((1.0, 0.0, 0.0), "x"), ((0.0, 1.0, 0.0), "y"), ((0.0, 0.0, 0.9), "z")] {
            let a = project(-end.0, -end.1, -end.2).point
            let b = project(end.0, end.1, end.2).point
            var line = Path()
            line.move(to: a); line.addLine(to: b)
            ctx.stroke(line, with: axisColor, lineWidth: 1)
            ctx.draw(Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary), at: b)
        }

        guard let f = expression else { return }

        // Sample the surface
        let stride = n + 1
        var zs = [Double](repeating: .nan, count: stride * stride)
        for j in 0...n {
            for i in 0...n {
                let x = -range + 2 * range * Double(i) / Double(n)
                let y = -range + 2 * range * Double(j) / Double(n)
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
                let pr = project(X, Y, h * 0.5)
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
            Picker("Range", selection: $range) {
                ForEach(Self.ranges, id: \.self) { r in Text("±\(formatNumber(r))").tag(r) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
