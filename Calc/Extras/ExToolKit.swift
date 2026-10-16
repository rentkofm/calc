import SwiftUI

// MARK: - Shared layout

/// Common layout for the Extras tools: a canvas that runs up to the top of the screen,
/// an "i" button for definitions, and a compact controls panel underneath.
struct ExToolPage<Display: View, Panel: View>: View {
    let info: [String]
    let panelHeight: CGFloat
    let display: Display
    let panel: Panel

    init(info: [String], panelHeight: CGFloat = 250,
         @ViewBuilder canvas: () -> Display, @ViewBuilder controls: () -> Panel) {
        self.info = info
        self.panelHeight = panelHeight
        self.display = canvas()
        self.panel = controls()
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                display
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(shape)
                    .glassEffect(.regular, in: shape)
                    .ignoresSafeArea(edges: .top)
                InfoButton(keys: info).padding(10)
            }
            ExPanel(maxHeight: panelHeight) { panel }
        }
    }
}

/// Glass controls panel that is only as tall as its content (up to `maxHeight`, then it scrolls).
struct ExPanel<Content: View>: View {
    let maxHeight: CGFloat
    let content: Content
    @State private var contentHeight: CGFloat = 0

    init(maxHeight: CGFloat = 250, @ViewBuilder content: () -> Content) {
        self.maxHeight = maxHeight
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) { content }
                .padding(14)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { contentHeight = $0 })
        }
        .frame(height: contentHeight > 0 ? min(contentHeight, maxHeight) : maxHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// A labelled slider with a live value.
struct ExParamRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    var format: String = "%.2f"

    var body: some View {
        HStack(spacing: 8) {
            Text(title).frame(width: 64, alignment: .leading)
            Group {
                if let step { Slider(value: $value, in: range, step: step) }
                else { Slider(value: $value, in: range) }
            }
            .accessibilityLabel(title)
            Text(String(format: format, value))
                .monospacedDigit()
                .frame(width: 66, alignment: .trailing)
        }
    }
}

/// Play / pause / reset row used by the animated tools.
struct ExTransport: View {
    @Binding var playing: Bool
    var onReset: (() -> Void)? = nil
    var onStep: (() -> Void)? = nil

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button { playing.toggle() } label: {
                    Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.glassProminent)
                if let onStep {
                    Button { onStep() } label: {
                        Label("Step", systemImage: "forward.frame.fill").frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)
                }
                if let onReset {
                    Button { onReset() } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}

// MARK: - "i" button

struct InfoButton: View {
    let keys: [String]
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Image(systemName: "info")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("Definitions and background")
        .sheet(isPresented: $show) { ReferenceInfoSheet(keys: keys) }
    }
}

// MARK: - Helpers

enum ExColor {
    static func hue(of c: Color) -> Double {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(h)
    }

    /// The accent with its hue rotated by `shift` (a fraction of the colour wheel).
    static func shifted(_ c: Color, by shift: Double, sat: Double = 0.75, bri: Double = 1) -> Color {
        let (r, g, b) = PendulumPalette.hsv(hue(of: c) + shift, sat, bri)
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

/// Minimal complex number for the Fourier and hyperbolic tools.
struct Cx: Equatable {
    var re: Double
    var im: Double
    init(_ re: Double, _ im: Double) { self.re = re; self.im = im }

    static let zero = Cx(0, 0)
    var abs: Double { hypot(re, im) }
    var abs2: Double { re * re + im * im }
    var conj: Cx { Cx(re, -im) }
    static func polar(_ r: Double, _ a: Double) -> Cx { Cx(r * cos(a), r * sin(a)) }

    static func + (a: Cx, b: Cx) -> Cx { Cx(a.re + b.re, a.im + b.im) }
    static func - (a: Cx, b: Cx) -> Cx { Cx(a.re - b.re, a.im - b.im) }
    static func * (a: Cx, b: Cx) -> Cx { Cx(a.re * b.re - a.im * b.im, a.re * b.im + a.im * b.re) }
    static func * (a: Cx, k: Double) -> Cx { Cx(a.re * k, a.im * k) }
    static func / (a: Cx, b: Cx) -> Cx {
        let d = b.abs2
        return Cx((a.re * b.re + a.im * b.im) / d, (a.im * b.re - a.re * b.im) / d)
    }
}

extension GraphicsContext {
    /// Strokes a polyline given as points.
    mutating func strokePolyline(_ pts: [CGPoint], color: Color, width: CGFloat = 2) {
        guard pts.count > 1 else { return }
        var p = Path()
        p.addLines(pts)
        stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}
