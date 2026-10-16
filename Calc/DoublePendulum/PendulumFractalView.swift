import SwiftUI

/// Lets a long-running background render notice it has been superseded.
private final class CancelToken: @unchecked Sendable {
    var cancelled = false
}

/// The classic double-pendulum "flip time" fractal: each point is a pair of starting angles
/// (θ₁ horizontally, θ₂ vertically), coloured by how long until a bob first flips over the top.
/// The dark regions never flip: the islands of stability.
/// Angles are periodic, so the picture tiles forever; pan and pinch to explore. "Grow" and "Live"
/// simulate every pixel forward in time and animate the result.
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
        /// Integration step: smaller is closer to the exact answer near chaotic boundaries.
        var dt: Double {
            switch self { case .fast: return 0.02; case .normal: return 0.01; case .fine: return 0.005 }
        }
        /// Pixel count for the animated modes.
        var animatedPixels: Double {
            switch self { case .fast: return 30_000; case .normal: return 60_000; case .fine: return 120_000 }
        }
    }

    enum Display: String, CaseIterable, Identifiable {
        case flipMap = "Flip map", grow = "Grow", live = "Live"
        var id: String { rawValue }
        var animated: Bool { self != .flipMap }
    }

    private struct Marker: Equatable { var t1: Double; var t2: Double }
    private struct RenderKey: Equatable {
        var display: Display
        var duration: Double
        var quality: Quality
        var highlight: Bool
        var accent: String
        var scheme: ColorScheme
        var size: CGSize
    }

    @State private var renderer = ProgressiveRenderer()
    @State private var field = PendulumField()
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

    @State private var display: Display = .flipMap
    @State private var duration = 10.0
    @State private var quality: Quality = .normal
    @State private var highlight = false
    @State private var playing = true
    @State private var timeSpeedExp = 0.0       // simulated seconds per real second = 2^exp
    @State private var holdUntil: Date?

    /// Scale at which one [-π, π] tile fits.
    private var fitScale: CGFloat { max(1, min(size.width, size.height) / (2 * .pi) * 0.98) }
    private var minScale: CGFloat { fitScale * 0.1 }
    private var maxScale: CGFloat { fitScale * 1e6 }

    private var renderKey: RenderKey {
        RenderKey(display: display, duration: duration, quality: quality, highlight: highlight,
                  accent: accent.description, scheme: scheme, size: size)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                canvas
                InfoButton(keys: infoKeys).padding(10)
            }
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
        if display.animated { seedField(); return }

        token.cancelled = true
        let tok = CancelToken()
        token = tok

        let sz = size
        let cx = center.doubleX, cy = center.doubleY, s = Double(scale)
        let limit = duration, minCell = quality.minCell, dt = quality.dt
        let palette = PendulumPalette(accent: accent, highlightStable: highlight)
        let hw = Double(sz.width) / 2, hh = Double(sz.height) / 2

        renderer.request(viewport: Viewport(center: center, scale: s, size: sz), displayScale: displayScale) { cell, quick in
            let c = quick ? cell : max(cell, minCell)
            return Raster.image(size: sz, cell: c) { sx, sy in
                // A superseded sharp render bails out fast; coarse in-motion frames always finish.
                if !quick && tok.cancelled { return (0, 0, 0) }
                // Angles are periodic, so the plane repeats forever.
                let t1 = PendulumPhysics.wrap(cx + (sx - hw) / s), t2 = PendulumPhysics.wrap(cy - (sy - hh) / s)
                guard let t = PendulumPhysics.flipTime(t1: t1, t2: t2, limit: limit, dt: dt) else { return palette.stable }
                return palette.flipColor(t, limit: limit)
            }
        }
    }

    private func seedField() {
        holdUntil = nil
        let sz = size
        let cell = Raster.cell(for: sz, displayScale: displayScale, maxPixels: quality.animatedPixels)
        field.reset(viewport: Viewport(center: center, scale: Double(scale), size: sz), cell: cell,
                    skipStable: display == .grow)
        drawField()
    }

    private func drawField() {
        field.updateImage(style: display == .live ? .live : .grow,
                          palette: PendulumPalette(accent: accent, highlightStable: highlight), limit: duration)
    }

    /// Advances the animated modes by the time since the last frame.
    private func tick(_ date: Date) {
        guard display.animated, playing, active, size.width > 0 else { field.lastTick = nil; return }
        let last = field.lastTick ?? date
        field.lastTick = date
        if let hold = holdUntil {
            if date >= hold { seedField() }   // loop: start again
            return
        }
        var dt = min(date.timeIntervalSince(last), 0.05) * pow(2, timeSpeedExp)
        if display == .grow { dt = min(dt, duration - field.time) }
        guard dt > 0 else {
            if display == .grow { holdUntil = date.addingTimeInterval(2) }
            return
        }
        field.advance(by: dt)
        drawField()
        if display == .grow && field.time >= duration - 1e-9 { holdUntil = date.addingTimeInterval(2) }
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
            if display.animated {
                ViewportImage(image: field.image, viewport: field.imageViewport,
                              center: center, scale: scale, size: size)
            } else {
                ViewportImage(image: renderer.image, viewport: renderer.viewport,
                              center: center, scale: scale, size: size)
            }
            markerView
            TimelineView(.animation(paused: !display.animated || !playing || !active)) { timeline in
                Color.clear
                    .onChange(of: timeline.date) { _, date in tick(date) }
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
        .ignoresSafeArea(edges: .top)
        .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(formatNumber(Double(scale / fitScale), digits: 3))×")
                if display.animated { Text("t = \(formatNumber(field.time, digits: 3)) s") }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .padding(10)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            if let m = marker {
                let t1 = PendulumPhysics.wrap(m.t1), t2 = PendulumPhysics.wrap(m.t2)
                Button {
                    model.launch(t1: t1, t2: t2)
                } label: {
                    Label(String(format: "Simulate  θ₁ %.4g°  θ₂ %.4g°", t1 * 180 / .pi, t2 * 180 / .pi),
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
                marker = Marker(t1: center.doubleX + Double(tap.location.x - size.width / 2) / Double(scale),
                                t2: center.doubleY - Double(tap.location.y - size.height / 2) / Double(scale))
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
            Picker("Display", selection: $display) {
                ForEach(Display.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

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

                    if display != .live {
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
            }

            if display.animated {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button { playing.toggle() } label: {
                            Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.glassProminent)

                        Button { seedField() } label: {
                            Label("Restart", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.glass)
                    }
                }
                HStack {
                    Label("Time", systemImage: "speedometer").frame(width: 80, alignment: .leading)
                    Slider(value: $timeSpeedExp, in: -2...4, step: 1)
                        .accessibilityLabel("Animation speed")
                    Text("\(formatNumber(pow(2, timeSpeedExp), digits: 3))×")
                        .monospacedDigit().frame(width: 56, alignment: .trailing)
                }
            }

            Toggle(isOn: $highlight) { Label("Highlight islands of stability", systemImage: "sparkles") }
                .padding(.horizontal, 4)
            Text(hint)
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var infoKeys: [String] {
        var keys = ["pendulum.fractal", "pendulum.flip", "pendulum.islands", "pendulum.tiling"]
        if display == .grow { keys.append("pendulum.grow") }
        if display == .live { keys.append("pendulum.live") }
        keys += ["pendulum.quality", "pendulum.chaos", "pendulum.locked"]
        return keys
    }

    private var hint: String {
        switch display {
        case .flipMap: return "Color = time until a bob flips. Dark = never flips in the simulated time. The picture repeats forever in both angles. Tap to pick a start."
        case .grow: return "Every pixel is a pendulum released at once: a pixel lights up when its pendulum flips. Panning or zooming restarts the clock."
        case .live: return "Every pixel is a live pendulum, colored by its current angles (hue θ₁, brightness θ₂). Panning or zooming restarts the clock."
        }
    }
}
