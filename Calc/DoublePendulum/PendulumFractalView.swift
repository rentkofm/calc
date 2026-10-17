import SwiftUI

/// Lets a long-running background render notice it has been superseded.
private final class CancelToken: @unchecked Sendable {
    var cancelled = false
}

/// Two views of the same fractal. "Angle space" is the classic one below. "Momentum space" fixes the starting
/// angles (the simulator's) and varies the starting canonical momenta (p₁ horizontally, p₂ vertically).
///
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
    @Environment(\.openExtras) private var openExtras

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

    enum Space: String, CaseIterable, Identifiable {
        case angle = "Angle space", momentum = "Momentum space"
        var id: String { rawValue }
    }

    /// Half-width of the momentum plane that fits the screen at 1×.
    private static let momentumHalfRange = 15.0

    enum Display: String, CaseIterable, Identifiable {
        case flipMap = "Flip map", grow = "Grow", live = "Live"
        var id: String { rawValue }
        var animated: Bool { self != .flipMap }
    }

    private struct Marker: Equatable { var t1: Double; var t2: Double }
    private struct RenderKey: Equatable {
        var space: Space
        var angles: [Double]
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

    @State private var space: Space = .angle
    @State private var display: Display = .flipMap
    @State private var duration = 10.0
    @State private var quality: Quality = .normal
    @State private var highlight = false
    @State private var playing = true
    @State private var timeSpeedExp = 0.0       // simulated seconds per real second = 2^exp
    @State private var holdUntil: Date?

    /// Scale at which one [-π, π] tile fits.
    private var fitScale: CGFloat {
        let span = space == .angle ? 2 * Double.pi : 2 * Self.momentumHalfRange
        return max(1, min(size.width, size.height) / CGFloat(span) * 0.98)
    }

    /// Starting angles for the momentum plane (the simulator's), or nil in angle space.
    private var fixedAngles: (t1: Double, t2: Double)? {
        space == .momentum ? (model.startT1, model.startT2) : nil
    }
    private var minScale: CGFloat { fitScale * 0.1 }
    private var maxScale: CGFloat { fitScale * 1e6 }

    private var renderKey: RenderKey {
        RenderKey(space: space, angles: space == .momentum ? [model.startT1, model.startT2] : [],
                  display: display, duration: duration, quality: quality, highlight: highlight,
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
        .onChange(of: space) { _, _ in
            marker = nil
            resetView()
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
        let fixed = fixedAngles

        renderer.request(viewport: Viewport(center: center, scale: s, size: sz), displayScale: displayScale) { cell, quick in
            let c = quick ? cell : max(cell, minCell)
            return Raster.image(size: sz, cell: c, cancelled: { !quick && tok.cancelled }) { sx, sy in
                // A superseded sharp render bails out fast; coarse in-motion frames always finish.
                if !quick && tok.cancelled { return (0, 0, 0) }
                if let a = fixed {
                    // Momentum plane: not periodic, started from the fixed angles.
                    let p1 = cx + (sx - hw) / s, p2 = cy - (sy - hh) / s
                    let v = PendulumPhysics.velocities(t1: a.t1, t2: a.t2, p1: p1, p2: p2)
                    guard let t = PendulumPhysics.flipTime(t1: a.t1, t2: a.t2, w1: v.w1, w2: v.w2, limit: limit,
                                                           dt: dt, adaptive: true) else { return palette.stable }
                    return palette.flipColor(t, limit: limit)
                }
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
                    skipStable: display == .grow && space == .angle, momentum: fixedAngles)
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
                picture(field.image, field.imageViewport)
            } else {
                picture(renderer.image, renderer.viewport)
            }
            if space == .momentum { originCross }
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
                if space == .momentum {
                    Text(String(format: "θ₁ %.4g°  θ₂ %.4g°  (p₁ →, p₂ ↑)", model.startT1 * 180 / .pi, model.startT2 * 180 / .pi))
                }
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
                let t1 = space == .angle ? PendulumPhysics.wrap(m.t1) : model.startT1
                let t2 = space == .angle ? PendulumPhysics.wrap(m.t2) : model.startT2
                let v = space == .angle ? (w1: 0.0, w2: 0.0)
                                        : PendulumPhysics.velocities(t1: t1, t2: t2, p1: m.t1, p2: m.t2)
                Button {
                    model.launch(t1: t1, t2: t2, w1: v.w1, w2: v.w2)
                } label: {
                    Label(space == .angle
                          ? String(format: "Simulate  θ₁ %.4g°  θ₂ %.4g°", t1 * 180 / .pi, t2 * 180 / .pi)
                          : String(format: "Simulate  p₁ %.4g  p₂ %.4g", m.t1, m.t2),
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

    /// Angle space tiles; the momentum plane is a single, non-repeating picture.
    @ViewBuilder
    private func picture(_ image: CGImage?, _ vp: Viewport) -> some View {
        if space == .angle {
            tiled(image, vp)
        } else if image != nil, vp.scale > 0, size.width > 0 {
            ViewportImage(image: image, viewport: vp, center: center, scale: scale, size: size)
        }
    }

    /// Axes through p₁ = p₂ = 0 (a pendulum released from rest).
    private var originCross: some View {
        let d = Center(x: 0, y: 0).difference(from: center)
        let o = CGPoint(x: size.width / 2 + CGFloat(d.dx) * scale, y: size.height / 2 - CGFloat(d.dy) * scale)
        return Path { p in
            p.move(to: CGPoint(x: 0, y: o.y)); p.addLine(to: CGPoint(x: size.width, y: o.y))
            p.move(to: CGPoint(x: o.x, y: 0)); p.addLine(to: CGPoint(x: o.x, y: size.height))
        }
        .stroke(Color.white.opacity(0.35), lineWidth: 1)
        .allowsHitTesting(false)
    }

    /// The picture repeats every 2π in both angles, so a frame that is a little behind the view (while panning
    /// or zooming out) is padded with copies of itself instead of showing an empty edge.
    @ViewBuilder
    private func tiled(_ image: CGImage?, _ vp: Viewport) -> some View {
        if image != nil, vp.scale > 0, size.width > 0 {
            let k = scale / CGFloat(vp.scale)
            let d = vp.center.difference(from: center)
            let period = 2 * Double.pi
            let w = vp.size.width * k, h = vp.size.height * k
            ForEach(Array([-1, 0, 1].flatMap { i in [-1, 0, 1].map { j in [i, j] } }), id: \.self) { ij in
                let dx = Double(ij[0]) * period, dy = Double(ij[1]) * period
                let cx = size.width / 2 + CGFloat((d.dx + dx) * Double(scale))
                let cy = size.height / 2 - CGFloat((d.dy + dy) * Double(scale))
                if abs(cx - size.width / 2) < (w + size.width) / 2, abs(cy - size.height / 2) < (h + size.height) / 2 {
                    ViewportImage(image: image, viewport: Viewport(center: vp.center.moved(dx: dx, dy: dy), scale: vp.scale, size: vp.size),
                                  center: center, scale: scale, size: size)
                }
            }
        }
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
            Picker("Space", selection: $space) {
                ForEach(Space.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

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

            Button { openExtras(.pendulum) } label: {
                Label("Double pendulum", systemImage: "waveform.path")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glass)

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
        if space == .momentum {
            let base = "Starting angles are fixed (the simulator's); each pixel is a starting momentum (p₁ →, p₂ ↑). The centre is released from rest and energy grows outward, so far from the centre everything flips quickly. Not periodic. Tap to pick a start."
            switch display {
            case .flipMap: return "Color = time until a bob flips. Dark = never flips in the simulated time. " + base
            case .grow: return "Every pixel is released at once and lights up when it flips. " + base
            case .live: return "Every pixel is live, colored by its current angles. " + base
            }
        }
        switch display {
        case .flipMap: return "Color = time until a bob flips. Dark = never flips in the simulated time. The picture repeats forever in both angles. Tap to pick a start."
        case .grow: return "Every pixel is a pendulum released at once: a pixel lights up when its pendulum flips. Panning or zooming restarts the clock."
        case .live: return "Every pixel is a live pendulum, colored by its current angles (hue θ₁, brightness θ₂). Panning or zooming restarts the clock."
        }
    }
}
