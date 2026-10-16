import SwiftUI

/// Lets a long-running background render notice it has been superseded.
private final class CancelToken: @unchecked Sendable {
    var cancelled = false
}

private struct PendulumPalette {
    var lut: [(UInt8, UInt8, UInt8)]
    var stable: (UInt8, UInt8, UInt8)

    init(accent: Color, highlightStable: Bool) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(accent).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        func rgb(_ hue: Double, _ sat: Double, _ bri: Double) -> (UInt8, UInt8, UInt8) {
            var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
            UIColor(hue: CGFloat(hue.truncatingRemainder(dividingBy: 1)), saturation: CGFloat(sat),
                    brightness: CGFloat(bri), alpha: 1).getRed(&r, green: &g, blue: &bl, alpha: &al)
            return (UInt8(r * 255), UInt8(g * 255), UInt8(bl * 255))
        }
        let hue = Double(h)
        lut = (0..<256).map { i in
            let x = Double(i) / 255
            return rgb(hue + 0.55 * x, 0.75, 1 - 0.35 * x)
        }
        stable = highlightStable ? rgb(hue, 0.08, 1) : rgb(hue, 0.6, 0.12)
    }
}

/// The classic double-pendulum "flip time" fractal: each point is a pair of starting angles
/// (θ₁ horizontally, θ₂ vertically), coloured by how long until a bob first flips over the top.
/// The dark regions never flip: the islands of stability. Pan and pinch to explore.
struct PendulumFractalView: View {
    let active: Bool

    @EnvironmentObject private var model: PendulumModel
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale

    enum Quality: String, CaseIterable, Identifiable {
        case fast = "Fast", normal = "Normal", fine = "Fine"
        var id: String { rawValue }
        /// Smallest rendered pixel, in points (smaller = sharper but slower).
        var minCell: CGFloat {
            switch self { case .fast: return 1.5; case .normal: return 0.75; case .fine: return 0.5 }
        }
    }

    private struct Marker: Equatable { var t1: Double; var t2: Double }
    private struct RenderKey: Equatable {
        var duration: Double
        var quality: Quality
        var highlight: Bool
        var accent: String
        var scheme: ColorScheme
        var size: CGSize
    }

    @State private var renderer = ProgressiveRenderer()
    @State private var inertia = Inertia()
    @State private var center = Center(x: 0, y: 0)
    @State private var scale: CGFloat = 60
    @State private var size: CGSize = .zero
    @State private var didFit = false
    @State private var stale = true
    @State private var token = CancelToken()
    @State private var dragOrigin: Center?
    @State private var scaleOrigin: CGFloat?
    @State private var marker: Marker?

    @State private var duration = 10.0
    @State private var quality: Quality = .normal
    @State private var highlight = false

    /// Scale at which the whole [-π, π] square fits.
    private var fitScale: CGFloat { max(1, min(size.width, size.height) / (2 * .pi) * 0.98) }
    private var minScale: CGFloat { fitScale * 0.4 }
    private var maxScale: CGFloat { fitScale * 1e6 }

    private var renderKey: RenderKey {
        RenderKey(duration: duration, quality: quality, highlight: highlight,
                  accent: accent.description, scheme: scheme, size: size)
    }

    var body: some View {
        VStack(spacing: 10) {
            canvas
            controls
        }
        .onChange(of: renderKey) { _, _ in
            if !didFit, size.width > 0 { scale = fitScale; didFit = true }
            refresh()
        }
        .onChange(of: center) { _, _ in refresh() }
        .onChange(of: scale) { _, _ in refresh() }
        .onChange(of: active) { _, now in
            if now && stale { refresh() }
        }
    }

    // MARK: Rendering

    private func refresh() {
        guard active, size.width > 0 else { stale = true; return }
        stale = false
        token.cancelled = true
        let tok = CancelToken()
        token = tok

        let sz = size
        let cx = center.doubleX, cy = center.doubleY, s = Double(scale)
        let limit = duration, minCell = quality.minCell
        let palette = PendulumPalette(accent: accent, highlightStable: highlight)
        let hw = Double(sz.width) / 2, hh = Double(sz.height) / 2

        renderer.request(viewport: Viewport(center: center, scale: s, size: sz), displayScale: displayScale) { cell, quick in
            let c = quick ? cell : max(cell, minCell)
            return Raster.image(size: sz, cell: c) { sx, sy in
                // A superseded sharp render bails out fast; coarse in-motion frames always finish.
                if !quick && tok.cancelled { return (0, 0, 0) }
                let t1 = cx + (sx - hw) / s, t2 = cy - (sy - hh) / s
                if abs(t1) > .pi || abs(t2) > .pi { return (0, 0, 0) }
                guard let t = PendulumPhysics.flipTime(t1: t1, t2: t2, limit: limit) else { return palette.stable }
                let x = min(1, log(1 + t) / log(1 + limit))
                return palette.lut[Int(x * 255)]
            }
        }
    }

    private func resetView() {
        inertia.stop()
        center = Center(x: 0, y: 0)
        scale = fitScale
    }

    // MARK: Canvas

    private var canvas: some View {
        ZStack {
            Color.black
            ViewportImage(image: renderer.image, viewport: renderer.viewport,
                          center: center, scale: scale, size: size)
            markerView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
        .ignoresSafeArea(edges: .top)
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
        .overlay(alignment: .bottomLeading) {
            Text("\(formatNumber(Double(scale / fitScale), digits: 3))×")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: Capsule())
                .padding(10)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            if let m = marker {
                Button {
                    model.launch(t1: m.t1, t2: m.t2)
                } label: {
                    Label(String(format: "Simulate  θ₁ %.4g°  θ₂ %.4g°", m.t1 * 180 / .pi, m.t2 * 180 / .pi),
                          systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(minHeight: 30)
                }
                .buttonStyle(.glassProminent)
                .padding(10)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in
                    if dragOrigin == nil { inertia.stop(); dragOrigin = center }
                    let o = dragOrigin ?? center
                    center = o.moved(dx: -Double(v.translation.width) / Double(scale),
                                     dy: Double(v.translation.height) / Double(scale))
                }
                .onEnded { v in
                    dragOrigin = nil
                    inertia.start(velocity: v.velocity) { dx, dy in
                        center = center.moved(dx: -dx / Double(scale), dy: dy / Double(scale))
                    }
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { v in
                    if scaleOrigin == nil { inertia.stop(); scaleOrigin = scale }
                    scale = min(max((scaleOrigin ?? scale) * v.magnification, minScale), maxScale)
                }
                .onEnded { _ in scaleOrigin = nil }
        )
        .simultaneousGesture(
            SpatialTapGesture(count: 1).onEnded { tap in
                if inertia.running { inertia.stop(); return }
                let t1 = center.doubleX + Double(tap.location.x - size.width / 2) / Double(scale)
                let t2 = center.doubleY - Double(tap.location.y - size.height / 2) / Double(scale)
                marker = (abs(t1) <= .pi && abs(t2) <= .pi) ? Marker(t1: t1, t2: t2) : nil
            }
        )
        .accessibilityLabel("Double pendulum fractal. Drag to pan, pinch to zoom, tap to pick a starting position.")
    }

    @ViewBuilder
    private var markerView: some View {
        if let m = marker, size.width > 0 {
            let d = Center(x: m.t1, y: m.t2).difference(from: center)
            let p = CGPoint(x: size.width / 2 + CGFloat(d.dx) * scale, y: size.height / 2 - CGFloat(d.dy) * scale)
            ZStack {
                Circle().stroke(Color.black.opacity(0.6), lineWidth: 4)
                Circle().stroke(Color.white, lineWidth: 2)
            }
            .frame(width: 18, height: 18)
            .position(p)
            .allowsHitTesting(false)
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 8) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button { resetView() } label: {
                        Label("Reset view", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)

                    Menu {
                        Picker("Quality", selection: $quality) {
                            ForEach(Quality.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label(quality.rawValue, systemImage: "square.grid.3x3")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Quality: \(quality.rawValue)")

                    Menu {
                        Picker("Simulated time", selection: $duration) {
                            ForEach([5.0, 10, 20, 40], id: \.self) { Text("\(Int($0)) s").tag($0) }
                        }
                    } label: {
                        Label("\(Int(duration)) s", systemImage: "timer")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Simulated time: \(Int(duration)) seconds")
                }
            }
            Toggle(isOn: $highlight) { Label("Highlight islands of stability", systemImage: "sparkles") }
                .padding(.horizontal, 4)
            Text("Color = time until a bob flips. Dark = never flips within the simulated time. Tap to pick a start.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
