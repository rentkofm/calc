import SwiftUI

// MARK: - Complex numbers

struct Complex {
    var re: Double
    var im: Double

    init(_ re: Double, _ im: Double = 0) { self.re = re; self.im = im }

    var modulus: Double { hypot(re, im) }
    var argument: Double { atan2(im, re) }

    static func + (a: Complex, b: Complex) -> Complex { Complex(a.re + b.re, a.im + b.im) }
    static func - (a: Complex, b: Complex) -> Complex { Complex(a.re - b.re, a.im - b.im) }
    static prefix func - (a: Complex) -> Complex { Complex(-a.re, -a.im) }
    static func * (a: Complex, b: Complex) -> Complex {
        Complex(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re)
    }
    static func / (a: Complex, b: Complex) -> Complex {
        let d = b.re * b.re + b.im * b.im
        return Complex((a.re * b.re + a.im * b.im) / d, (a.im * b.re - a.re * b.im) / d)
    }
}

enum CMath {
    static func cexp(_ z: Complex) -> Complex {
        let e = exp(z.re)
        return Complex(e * cos(z.im), e * sin(z.im))
    }
    static func clog(_ z: Complex) -> Complex { Complex(log(z.modulus), z.argument) }
    static func csqrt(_ z: Complex) -> Complex {
        let r = z.modulus
        let re = sqrt((r + z.re) / 2)
        let im = sqrt(max(0, (r - z.re) / 2))
        return Complex(re, z.im < 0 ? -im : im)
    }
    static func csin(_ z: Complex) -> Complex { Complex(sin(z.re) * cosh(z.im), cos(z.re) * sinh(z.im)) }
    static func ccos(_ z: Complex) -> Complex { Complex(cos(z.re) * cosh(z.im), -sin(z.re) * sinh(z.im)) }
    static func csinh(_ z: Complex) -> Complex { Complex(sinh(z.re) * cos(z.im), cosh(z.re) * sin(z.im)) }
    static func ccosh(_ z: Complex) -> Complex { Complex(cosh(z.re) * cos(z.im), sinh(z.re) * sin(z.im)) }

    static func cpow(_ a: Complex, _ b: Complex) -> Complex {
        if b.im == 0, b.re == b.re.rounded(), abs(b.re) <= 64 {
            var n = Int(abs(b.re))
            var result = Complex(1), base = a
            while n > 0 {
                if n & 1 == 1 { result = result * base }
                base = base * base
                n >>= 1
            }
            return b.re < 0 ? Complex(1) / result : result
        }
        if a.re == 0 && a.im == 0 { return b.re > 0 ? Complex(0) : Complex(.nan, .nan) }
        return cexp(b * clog(a))
    }

    static func apply(_ name: String, _ z: Complex) -> Complex {
        switch name {
        case "sin": return csin(z)
        case "cos": return ccos(z)
        case "tan": return csin(z) / ccos(z)
        case "sinh": return csinh(z)
        case "cosh": return ccosh(z)
        case "tanh": return csinh(z) / ccosh(z)
        case "exp": return cexp(z)
        case "ln": return clog(z)
        case "log": return clog(z) / Complex(log(10))
        case "sqrt": return csqrt(z)
        case "abs": return Complex(z.modulus)
        case "re": return Complex(z.re)
        case "im": return Complex(z.im)
        case "conj": return Complex(z.re, -z.im)
        case "arg": return Complex(z.argument)
        default: return Complex(.nan, .nan)
        }
    }
}

// MARK: - Parser

typealias ComplexFn = (Complex) -> Complex

/// Same grammar as `Parser`, but over complex numbers with variable `z` and constant `i`.
struct ComplexParser {
    private static let functionNames = ["sin", "cos", "tan", "sinh", "cosh", "tanh", "exp", "ln", "log",
                                        "sqrt", "abs", "re", "im", "conj", "arg"]
    private static let names = functionNames + ["pi", "e", "z", "i"]

    private let c: [Character]
    private var pos = 0

    private init(_ text: String) {
        var s = text
        for (a, b) in [("×", "*"), ("÷", "/"), ("−", "-"), ("·", "*"), ("π", "pi"), ("√", "sqrt")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        c = Array(s.filter { !$0.isWhitespace })
    }

    static func compile(_ text: String) throws -> ComplexFn {
        var p = ComplexParser(text)
        guard !p.c.isEmpty else { throw ParseError() }
        let f = try p.expression()
        guard p.pos == p.c.count else { throw ParseError() }
        return f
    }

    private var peek: Character? { pos < c.count ? c[pos] : nil }

    private mutating func expression() throws -> ComplexFn {
        var lhs = try term()
        while let ch = peek, ch == "+" || ch == "-" {
            pos += 1
            let rhs = try term()
            let l = lhs
            lhs = ch == "+" ? { l($0) + rhs($0) } : { l($0) - rhs($0) }
        }
        return lhs
    }

    private mutating func term() throws -> ComplexFn {
        var lhs = try unary()
        while let ch = peek {
            let l = lhs
            if ch == "*" || ch == "/" {
                pos += 1
                let rhs = try unary()
                lhs = ch == "*" ? { l($0) * rhs($0) } : { l($0) / rhs($0) }
            } else if ch == "(" || ch == "." || ch.isLetter || ch.isNumber {
                let rhs = try unary()
                lhs = { l($0) * rhs($0) }
            } else {
                break
            }
        }
        return lhs
    }

    private mutating func unary() throws -> ComplexFn {
        if let ch = peek, ch == "-" || ch == "+" {
            pos += 1
            let f = try unary()
            return ch == "-" ? { -f($0) } : f
        }
        return try power()
    }

    private mutating func power() throws -> ComplexFn {
        let base = try primary()
        if peek == "^" {
            pos += 1
            let exponent = try unary()
            return { CMath.cpow(base($0), exponent($0)) }
        }
        return base
    }

    private mutating func primary() throws -> ComplexFn {
        guard let ch = peek else { throw ParseError() }
        if ch.isNumber || ch == "." { return try number() }
        if ch == "(" {
            pos += 1
            let f = try expression()
            if peek == ")" { pos += 1 } else if pos < c.count { throw ParseError() }
            return f
        }
        if ch.isLetter { return try identifier() }
        throw ParseError()
    }

    private mutating func number() throws -> ComplexFn {
        let start = pos
        while let ch = peek, ch.isNumber || ch == "." { pos += 1 }
        if let e = peek, e == "e" || e == "E" {
            var j = pos + 1
            if j < c.count, c[j] == "+" || c[j] == "-" { j += 1 }
            if j < c.count, c[j].isNumber {
                while j < c.count, c[j].isNumber { j += 1 }
                pos = j
            }
        }
        guard let v = Double(String(c[start..<pos])) else { throw ParseError() }
        let z = Complex(v)
        return { _ in z }
    }

    private mutating func identifier() throws -> ComplexFn {
        let rest = String(c[pos...])
        guard let name = Self.names.filter({ rest.hasPrefix($0) }).max(by: { $0.count < $1.count }) else {
            throw ParseError()
        }
        pos += name.count
        switch name {
        case "z": return { $0 }
        case "i": return { _ in Complex(0, 1) }
        case "pi": return { _ in Complex(.pi) }
        case "e": return { _ in Complex(M_E) }
        default: break
        }
        let arg: ComplexFn
        if peek == "(" { arg = try primary() } else { arg = try power() }
        return { CMath.apply(name, arg($0)) }
    }
}

// MARK: - View

/// Domain coloring of f(z): hue is the argument, brightness bands show the modulus.
struct ComplexGraphView: View {
    private static let presets: [(name: String, expr: String)] = [
        ("z³ − 1", "z^3-1"),
        ("z²", "z^2"),
        ("1/z", "1/z"),
        ("sin z", "sin(z)"),
        ("eᶻ", "exp(z)"),
        ("√z", "sqrt(z)"),
        ("ln z", "ln(z)"),
        ("Möbius", "(z-1)/(z+1)"),
    ]
    private static let chips = ["z", "i", "^", "(", ")", "π", "e", "sin(", "cos(", "exp(", "ln(", "sqrt(", "conj(", "abs("]

    @State private var text = "z^3-1"
    @State private var center = CGPoint.zero
    @State private var scale: CGFloat = 60
    @State private var size = CGSize(width: 320, height: 320)
    @State private var dragOrigin: CGPoint?
    @State private var scaleOrigin: CGFloat?
    @State private var probe: Complex?
    @State private var renderer = ProgressiveRenderer()
    @State private var inertia = Inertia()
    @Environment(\.displayScale) private var displayScale
    @Environment(\.graphFullscreen) private var fullscreen
    @FocusState private var focused: Bool

    private var function: ComplexFn? {
        var s = text.filter { !$0.isWhitespace }
        if s.lowercased().hasPrefix("f(z)=") { s.removeFirst(5) }
        return try? ComplexParser.compile(s)
    }

    var body: some View {
        VStack(spacing: 12) {
            plane
            if !fullscreen.wrappedValue {
                if focused { chipRow } else { presetRow }
                inputCard
            }
        }
        .modifier(GraphPage())
        .onChange(of: text) { probe = nil }
        .onChange(of: renderKey) { refresh() }
        .onAppear { refresh() }
    }

    private struct RenderKey: Equatable {
        var cx: Double, cy: Double, scale: Double
        var size: CGSize
        var text: String
    }

    private var renderKey: RenderKey {
        RenderKey(cx: Double(center.x), cy: Double(center.y), scale: Double(scale), size: size, text: text)
    }

    private func refresh() {
        guard let f = function else { renderer.clear(); return }
        let (sz, c, sc) = (size, center, scale)
        renderer.request(viewport: Viewport(center: Center(x: Double(c.x), y: Double(c.y)), scale: Double(sc), size: sz),
                         displayScale: displayScale) { cell, _ in
            ComplexRenderer.render(f, size: sz, center: c, scale: sc, cell: cell)
        }
    }

    // MARK: Plane

    private var plane: some View {
        ZStack {
            ViewportImage(image: renderer.image, viewport: renderer.viewport,
                          center: Center(x: Double(center.x), y: Double(center.y)), scale: scale, size: size)
            Canvas { ctx, size in drawAxes(ctx, size) }
            probeOverlay
        }
        .frame(minHeight: 200)
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
        .modifier(GraphSurface())
        .overlay(alignment: .topTrailing) {
            if !fullscreen.wrappedValue { EnterFullscreenButton().padding(10) }
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in
                    if dragOrigin == nil { inertia.stop(); dragOrigin = center }
                    let o = dragOrigin ?? center
                    center = CGPoint(x: o.x - v.translation.width / scale,
                                     y: o.y + v.translation.height / scale)
                }
                .onEnded { v in
                    dragOrigin = nil
                    inertia.start(velocity: v.velocity) { dx, dy in
                        center.x -= CGFloat(dx) / scale
                        center.y += CGFloat(dy) / scale
                    }
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { v in
                    if scaleOrigin == nil { inertia.stop(); scaleOrigin = scale }
                    scale = min(max((scaleOrigin ?? scale) * v.magnification, 1e-100), 1e100)
                }
                .onEnded { _ in scaleOrigin = nil }
        )
        .onTapGesture { location in
            if inertia.running { inertia.stop(); return } // the first tap just catches the plane
            guard function != nil else { return }
            probe = toComplex(location, size)
            Haptics.tap()
        }
    }

    private func toComplex(_ p: CGPoint, _ size: CGSize) -> Complex {
        Complex(Double(center.x) + Double(p.x - size.width / 2) / Double(scale),
                Double(center.y) - Double(p.y - size.height / 2) / Double(scale))
    }

    private func toScreen(_ z: Complex, _ size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + CGFloat(z.re - Double(center.x)) * scale,
                y: size.height / 2 - CGFloat(z.im - Double(center.y)) * scale)
    }

    private func drawAxes(_ ctx: GraphicsContext, _ size: CGSize) {
        let step = GraphView.niceStep(60.0 / Double(scale))
        let minX = Double(center.x) - Double(size.width / 2 / scale)
        let maxX = Double(center.x) + Double(size.width / 2 / scale)
        let minY = Double(center.y) - Double(size.height / 2 / scale)
        let maxY = Double(center.y) + Double(size.height / 2 / scale)
        let origin = toScreen(Complex(0, 0), size)

        var axes = Path()
        axes.move(to: CGPoint(x: 0, y: origin.y)); axes.addLine(to: CGPoint(x: size.width, y: origin.y))
        axes.move(to: CGPoint(x: origin.x, y: 0)); axes.addLine(to: CGPoint(x: origin.x, y: size.height))
        ctx.stroke(axes, with: .color(.white.opacity(0.8)), lineWidth: 1)

        let labelY = min(max(origin.y + 3, 4), size.height - 16)
        let labelX = min(max(origin.x + 4, 4), size.width - 36)
        for x in GraphView.gridValues(minX, maxX, step) where abs(x) > step / 2 {
            ctx.draw(Text(formatNumber(x, digits: 6)).font(.caption2).foregroundStyle(.white),
                     at: CGPoint(x: toScreen(Complex(x, 0), size).x, y: labelY), anchor: .top)
        }
        for y in GraphView.gridValues(minY, maxY, step) where abs(y) > step / 2 {
            ctx.draw(Text(formatNumber(y, digits: 6) + "i").font(.caption2).foregroundStyle(.white),
                     at: CGPoint(x: labelX, y: toScreen(Complex(0, y), size).y), anchor: .leading)
        }
    }

    @ViewBuilder
    private var probeOverlay: some View {
        GeometryReader { geo in
            if let z = probe, let f = function, case let p = toScreen(z, geo.size),
               CGRect(origin: .zero, size: geo.size).contains(p) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 2))
                        .position(p)
                    VStack(spacing: 2) {
                        Text("z = \(Self.format(z))")
                        Text("f(z) = \(Self.format(f(z)))")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .position(x: min(max(p.x, 100), geo.size.width - 100),
                              y: p.y < 70 ? p.y + 46 : p.y - 46)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 28))
        .allowsHitTesting(false)
    }

    private static func format(_ z: Complex) -> String {
        guard z.re.isFinite, z.im.isFinite else { return "undefined" }
        let re = formatNumber(z.re, digits: 4)
        let im = formatNumber(abs(z.im), digits: 4)
        return "\(re) \(z.im < 0 ? "−" : "+") \(im)i"
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
                    ForEach(Self.chips, id: \.self) { chip in
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
            Text("f(z) =").foregroundStyle(.secondary)
            TextField("e.g. z^2 + i", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
            if !text.isEmpty && function == nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
