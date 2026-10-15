import SwiftUI

struct GraphFunction: Identifiable {
    let id = UUID()
    var text: String
    let colorIndex: Int
}

struct GraphView: View {
    private static let palette: [Color] = [.blue, .orange, .green, .pink]
    private static let chips = ["x", "^", "(", ")", "π", "e", "sin(", "cos(", "tan(", "ln(", "log(", "√(", "abs("]

    @Environment(\.appAccent) private var accent
    @AppStorage("graphGrid") private var showGrid = true

    @State private var functions = [GraphFunction(text: "sin(x)", colorIndex: 0)]
    @State private var center = CGPoint.zero
    @State private var scale: CGFloat = 40
    @State private var dragOrigin: CGPoint?
    @State private var scaleOrigin: CGFloat?
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
        }
    }

    // MARK: Canvas

    private var graph: some View {
        Canvas { ctx, size in draw(ctx, size) }
            .frame(minHeight: 220)
            .clipShape(.rect(cornerRadius: 28))
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if dragOrigin == nil { dragOrigin = center }
                        let o = dragOrigin ?? center
                        center = CGPoint(x: o.x - v.translation.width / scale,
                                         y: o.y + v.translation.height / scale)
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if scaleOrigin == nil { scaleOrigin = scale }
                        scale = min(max((scaleOrigin ?? scale) * v.magnification, 5), 4000)
                    }
                    .onEnded { _ in scaleOrigin = nil }
            )
            .overlay(alignment: .topTrailing) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        roundButton("minus") { withAnimation(.smooth) { scale = max(scale / 1.5, 5) } }
                        roundButton("plus") { withAnimation(.smooth) { scale = min(scale * 1.5, 4000) } }
                        roundButton("arrow.counterclockwise") {
                            withAnimation(.smooth) { center = .zero; scale = 40 }
                        }
                    }
                }
                .padding(10)
            }
    }

    private func roundButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let s = scale
        func px(_ x: Double) -> CGFloat { size.width / 2 + CGFloat(x - center.x) * s }
        func py(_ y: Double) -> CGFloat { size.height / 2 - CGFloat(y - center.y) * s }

        let step = Self.niceStep(1.0 / Double(s) * 60)
        let minX = Double(center.x) - Double(size.width / 2 / s)
        let maxX = Double(center.x) + Double(size.width / 2 / s)
        let minY = Double(center.y) - Double(size.height / 2 / s)
        let maxY = Double(center.y) + Double(size.height / 2 / s)

        // Grid
        if showGrid {
            var grid = Path()
            var gx = (minX / step).rounded(.up) * step
            while gx <= maxX {
                grid.move(to: CGPoint(x: px(gx), y: 0)); grid.addLine(to: CGPoint(x: px(gx), y: size.height))
                gx += step
            }
            var gy = (minY / step).rounded(.up) * step
            while gy <= maxY {
                grid.move(to: CGPoint(x: 0, y: py(gy))); grid.addLine(to: CGPoint(x: size.width, y: py(gy)))
                gy += step
            }
            ctx.stroke(grid, with: .color(.secondary.opacity(0.25)), lineWidth: 0.5)
        }

        // Axes
        var axes = Path()
        axes.move(to: CGPoint(x: 0, y: py(0))); axes.addLine(to: CGPoint(x: size.width, y: py(0)))
        axes.move(to: CGPoint(x: px(0), y: 0)); axes.addLine(to: CGPoint(x: px(0), y: size.height))
        ctx.stroke(axes, with: .color(.secondary.opacity(0.8)), lineWidth: 1)

        // Labels
        let labelY = min(max(py(0) + 3, 4), size.height - 16)
        let labelX = min(max(px(0) + 4, 4), size.width - 36)
        var lx = (minX / step).rounded(.up) * step
        while lx <= maxX {
            if abs(lx) > step / 2 {
                ctx.draw(Text(Self.label(lx)).font(.caption2).foregroundStyle(.secondary),
                         at: CGPoint(x: px(lx), y: labelY), anchor: .top)
            }
            lx += step
        }
        var ly = (minY / step).rounded(.up) * step
        while ly <= maxY {
            if abs(ly) > step / 2 {
                ctx.draw(Text(Self.label(ly)).font(.caption2).foregroundStyle(.secondary),
                         at: CGPoint(x: labelX, y: py(ly)), anchor: .leading)
            }
            ly += step
        }

        // Curves
        for fn in functions {
            guard let f = try? Parser.compile(fn.text, angle: .radians) else { continue }
            var path = Path()
            var prevY: CGFloat?
            for i in 0...Int(size.width) {
                let x = Double(center.x) + (Double(i) - Double(size.width) / 2) / Double(s)
                let y = f(x)
                guard y.isFinite else { prevY = nil; continue }
                let p = CGPoint(x: CGFloat(i), y: py(y))
                if abs(p.y) > 1e6 { prevY = nil; continue }
                if let pv = prevY, abs(p.y - pv) < size.height * 2 {
                    path.addLine(to: p)
                } else {
                    path.move(to: p)
                }
                prevY = p.y
            }
            ctx.stroke(path, with: .color(Self.palette[fn.colorIndex % Self.palette.count]),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
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
        VStack(spacing: 0) {
            ForEach($functions) { $fn in
                let valid = fn.text.isEmpty || (try? Parser.compile(fn.text, angle: .radians)) != nil
                HStack(spacing: 10) {
                    Circle().fill(Self.palette[fn.colorIndex % Self.palette.count]).frame(width: 12, height: 12)
                    Text("y =").foregroundStyle(.secondary)
                    TextField("f(x)", text: $fn.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: fn.id)
                    if !valid {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                    if functions.count > 1 {
                        Button {
                            withAnimation { functions.removeAll { $0.id == fn.id } }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 10)
                if fn.id != functions.last?.id { Divider() }
            }
            if functions.count < Self.palette.count {
                Divider()
                Button {
                    let used = Set(functions.map(\.colorIndex))
                    let next = (0..<Self.palette.count).first { !used.contains($0) } ?? 0
                    let new = GraphFunction(text: "", colorIndex: next)
                    withAnimation { functions.append(new) }
                    focused = new.id
                } label: {
                    Label("Add Function", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
