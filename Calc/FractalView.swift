import SwiftUI

struct FractalView: View {
    private static let juliaPresets: [(re: Double, im: Double)] = [
        (-0.8, 0.156), (-0.4, 0.6), (0.285, 0.01), (-0.70176, -0.3842), (0.355, 0.355), (-0.835, -0.2321), (0, 1),
    ]

    @Environment(\.appAccent) private var accent
    @Environment(\.displayScale) private var displayScale

    @State private var kind: FractalKind = .mandelbrot
    @State private var palette: FractalPalette = .deepBlue
    @State private var coloring: FractalColoring = .smooth
    @State private var juliaIndex = 0
    @State private var variant = 0
    @State private var detail = 150.0
    @State private var power = 2.0
    @State private var zoomSpeed = 1.0 // doublings per second
    @State private var morph = 0.0     // Mandelbrot form (0) → Julia form (1)
    @State private var coef = 1.0
    @State private var customRe = -0.8
    @State private var customIm = 0.156

    @State private var center: Center = FractalKind.mandelbrot.defaultCenter
    @State private var scale: CGFloat = FractalKind.mandelbrot.defaultScale
    @State private var rotation = 0.0 // two-finger twist of the 2D view
    @State private var roll = 0.0      // the same twist, as camera roll in 3D
    @State private var twistOrigin: Double?
    @State private var yaw = 0.6
    @State private var pitch = 0.35
    @State private var dist = 3.0
    @State private var target = SIMD3<Double>(0, 0, 0)

    @State private var size = CGSize(width: 320, height: 320)
    @State private var renderer = ProgressiveRenderer()
    @State private var accumulator = AccumulationRenderer()
    @State private var dragOrigin: Center?
    @State private var rotOrigin: (yaw: Double, pitch: Double)?
    @State private var scaleOrigin: CGFloat?
    @State private var distOrigin: Double?
    @State private var inertia = Inertia()
    @State private var autoZoomTask: Task<Void, Never>?
    @State private var isFullscreen = false
    @State private var controlsHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            canvas
            if !isFullscreen {
                categoryChips
                kindChips
                controls
            }
        }
        .padding(.horizontal, isFullscreen ? 0 : 16)
        .padding(.bottom, isFullscreen ? 0 : 8)
        .frame(maxWidth: isFullscreen ? .infinity : 720)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if isFullscreen { closeButton.padding(12) }
        }
        .safeAreaInset(edge: .bottom) {
            if isFullscreen {
                HStack(spacing: 10) {
                    Spacer()
                    zoomButton
                    closeButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .toolbar(isFullscreen ? .hidden : .automatic, for: .tabBar)
        .toolbar(isFullscreen ? .hidden : .automatic, for: .navigationBar)
        .onChange(of: renderKey) { refresh() }
        .onChange(of: kind) { selectDefaults() }
        .onAppear { selectDefaults() }
    }

    // MARK: State derived from the controls

    private var maxIter: Int {
        guard kind.detailSpec != nil else { return 50 }
        if kind.usesZoomBoost {
            let boost = 60 * max(0, log2(Double(scale / kind.defaultScale)))
            return min(Int(detail + boost), 100_000)
        }
        return Int(detail)
    }

    private var params: FractalParams {
        FractalParams(kind: kind, palette: palette, coloring: coloring, center: center, scale: scale,
                      maxIter: maxIter,
                      juliaC: kind == .custom ? (re: customRe, im: customIm) : Self.juliaPresets[juliaIndex],
                      power: power, variant: variant, rotation: rotation, morph: morph, coef: coef)
    }

    private var ray3DParams: Ray3DParams {
        Ray3DParams(kind: kind, palette: palette, yaw: yaw, pitch: pitch, dist: dist, target: target,
                    power: power, iterations: Int(detail), roll: roll)
    }

    private struct RenderKey: Equatable {
        var kind: FractalKind
        var palette: FractalPalette
        var coloring: FractalColoring
        var juliaIndex: Int
        var variant: Int
        var detail: Double
        var power: Double
        var center: Center
        var scale: Double
        var size: CGSize
        var yaw: Double
        var pitch: Double
        var dist: Double
        var target: SIMD3<Double>
        var rotation: Double
        var roll: Double
        var accent: [Double]
        var morph: Double
        var coef: Double
        var customRe: Double
        var customIm: Double
    }

    private var renderKey: RenderKey {
        RenderKey(kind: kind, palette: palette, coloring: coloring, juliaIndex: juliaIndex, variant: variant,
                  detail: detail, power: power, center: center, scale: Double(scale), size: size,
                  yaw: yaw, pitch: pitch, dist: dist, target: target, rotation: rotation, roll: roll,
                  accent: accentComponents, morph: morph, coef: coef, customRe: customRe, customIm: customIm)
    }

    // MARK: Rendering

    private var accentComponents: [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(accent).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Double(r), Double(g), Double(b)]
    }

    private func publishAccent() {
        let c = accentComponents
        FractalPalette.accentRGB = (c[0], c[1], c[2])
    }

    private func refresh() {
        publishAccent()
        let sz = size
        switch kind.style {
        case .raster:
            let full = params
            renderer.request(viewport: Viewport(center: center, scale: Double(scale), size: sz, rotation: rotation),
                             displayScale: displayScale) { cell, quick in
                var p = full
                if quick { p.maxIter = min(p.maxIter, 800) } // keep the in-motion frames quick
                return FractalRenderer.render(p, size: sz, cell: cell)
            }
        case .ray3D:
            let rp = ray3DParams
            renderer.request(viewport: Viewport(center: Center(x: 0, y: 0), scale: 1, size: sz),
                             displayScale: displayScale) { cell, quick in
                // Ray marching is expensive: coarse while moving, ~1 point per pixel once still.
                Fractal3D.render(rp, size: sz, cell: quick ? max(cell, 2) : max(cell, 1.2))
            }
        case .accumulate:
            accumulator.start(viewport: Viewport(center: center, scale: Double(scale), size: sz, rotation: rotation),
                              spec: Accumulate.spec(for: params))
        case .vector:
            break // drawn live by the canvas
        }
    }

    private func selectDefaults() {
        stopMotion()
        center = kind.defaultCenter
        scale = kind.defaultScale
        detail = kind.detailSpec?.defaultValue ?? 0
        power = kind.powerSpec?.defaultValue ?? 2
        variant = 0
        morph = kind.baseMorph
        coef = 1
        customRe = -0.8
        customIm = 0.156
        if !kind.supportsColoring { coloring = .smooth }
        resetCamera()
        renderer.clear()
        accumulator.clear()
        refresh()
    }

    private func resetCamera() {
        rotation = 0
        roll = 0
        yaw = 0.6
        pitch = 0.35
        dist = kind.defaultDistance
        target = SIMD3<Double>(0, 0, 0)
    }

    private func resetView() {
        stopMotion()
        center = kind.defaultCenter
        scale = kind.defaultScale
        resetCamera()
    }

    // MARK: Motion

    /// Converts a screen-space offset (points, y up) into plane units, honoring the twist.
    private func planeOffset(_ sx: Double, _ syUp: Double) -> (Double, Double) {
        let c = cos(rotation), s = sin(rotation), k = Double(scale)
        return ((sx * c - syUp * s) / k, (sx * s + syUp * c) / k)
    }

    private func stopMotion() {
        inertia.stop()
        autoZoomTask?.cancel()
        autoZoomTask = nil
    }

    private func startAutoZoom(at point: CGPoint) {
        stopMotion()
        Haptics.tap()
        if kind.style == .ray3D { startAutoDolly(at: point); return }

        // Zoom toward `point` at a constant exponential rate, easing it to the middle of the view.
        let first = planeOffset(Double(point.x - size.width / 2), -Double(point.y - size.height / 2))
        let zoomTarget = center.moved(dx: first.0, dy: first.1)
        var screen = point
        autoZoomTask = Task { @MainActor in
            var last = ContinuousClock.now
            while !Task.isCancelled && scale < kind.maxScale {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                let now = ContinuousClock.now
                let dt = min(0.05, (now - last) / .seconds(1))
                last = now
                let ease = CGFloat(1 - exp(-3 * dt))
                screen.x += (size.width / 2 - screen.x) * ease
                screen.y += (size.height / 2 - screen.y) * ease
                scale *= CGFloat(pow(2, zoomSpeed * dt))
                let o = planeOffset(Double(screen.x - size.width / 2), -Double(screen.y - size.height / 2))
                center = zoomTarget.moved(dx: -o.0, dy: -o.1)
            }
            autoZoomTask = nil
        }
    }

    /// 3D: turn toward the tapped surface point, then fly straight at it.
    private func startAutoDolly(at point: CGPoint) {
        let rp = ray3DParams
        let hit = Fractal3D.cast(rp, size: size, at: point) ?? target
        let camPos = Fractal3D.cameraPosition(rp)
        autoZoomTask = Task { @MainActor in
            let start = target
            var glide = 0.0
            var last = ContinuousClock.now
            while !Task.isCancelled && glide < 1 {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                let now = ContinuousClock.now
                glide = min(1, glide + min(0.05, (now - last) / .seconds(1)) / 0.6)
                last = now
                let e = glide * glide * (3 - 2 * glide)
                target = start + (hit - start) * e
                lookAt(from: camPos)
            }
            while !Task.isCancelled && dist > 1e-9 {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                let now = ContinuousClock.now
                let dt = min(0.05, (now - last) / .seconds(1))
                last = now
                dist *= pow(2, -zoomSpeed * dt)
            }
            autoZoomTask = nil
        }
    }

    /// Re-aim the camera at `target` without moving it.
    private func lookAt(from pos: SIMD3<Double>) {
        let v = pos - target
        let d = (v * v).sum().squareRoot()
        guard d > 0 else { return }
        dist = d
        yaw = atan2(v.x, v.z)
        pitch = asin(max(-1, min(1, v.y / d)))
    }

    // MARK: Buttons

    private var closeButton: some View {
        Button {
            withAnimation(.smooth) { isFullscreen = false }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("Close full screen")
    }

    /// Zooms in on the middle of the view until tapped again (or until you drag or pinch).
    private var zoomButton: some View {
        let running = autoZoomTask != nil
        return Button {
            if autoZoomTask != nil {
                stopMotion()
            } else {
                startAutoZoom(at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
        } label: {
            Image(systemName: running ? "pause.fill" : "plus.magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(running ? .regular.tint(accent).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityLabel(running ? "Stop zooming" : "Zoom in")
    }

    // MARK: Canvas

    private var canvasContent: some View {
        ZStack {
            Color.black
            switch kind.style {
            case .raster:
                ViewportImage(image: renderer.image, viewport: renderer.viewport,
                              center: center, scale: scale, size: size, rotation: rotation)
            case .accumulate:
                ViewportImage(image: accumulator.image, viewport: accumulator.viewport,
                              center: center, scale: scale, size: size, rotation: rotation)
            case .vector:
                Canvas { ctx, sz in
                    publishAccent()
                    VectorFractals.draw(ctx, size: sz, p: params)
                }
            case .ray3D:
                if let image = renderer.image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.medium)
                }
            }
        }
    }

    private var badge: String {
        if kind.style == .ray3D { return "\(formatNumber(kind.defaultDistance / dist, digits: 3))×" }
        let zoom = "\(formatNumber(Double(scale / kind.defaultScale), digits: 3))×"
        return kind.style == .raster && kind.detailSpec != nil ? "\(zoom) · \(maxIter) iterations" : zoom
    }

    private var canvas: some View {
        canvasContent
            .frame(minHeight: 220)
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
            .overlay(alignment: .bottomLeading) {
                if !isFullscreen {
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: Capsule())
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !isFullscreen {
                    Button {
                        withAnimation(.smooth) { isFullscreen = true }
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .padding(10)
                    .accessibilityLabel("Full screen")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !isFullscreen { zoomButton.padding(10) }
            }
            .clipShape(.rect(cornerRadius: isFullscreen ? 0 : 28))
            .glassEffect(isFullscreen ? .identity : .regular, in: .rect(cornerRadius: isFullscreen ? 0 : 28))
            .ignoresSafeArea(isFullscreen ? .all : [])
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        if kind.style == .ray3D {
                            if rotOrigin == nil { stopMotion(); rotOrigin = (yaw, pitch) }
                            let o = rotOrigin ?? (yaw, pitch)
                            yaw = o.yaw - Double(v.translation.width) * 0.008
                            pitch = min(max(o.pitch + Double(v.translation.height) * 0.008, -1.5), 1.5)
                        } else {
                            if dragOrigin == nil { stopMotion(); dragOrigin = center }
                            let o = dragOrigin ?? center
                            let d = planeOffset(Double(v.translation.width), -Double(v.translation.height))
                            center = o.moved(dx: -d.0, dy: -d.1)
                        }
                    }
                    .onEnded { v in
                        dragOrigin = nil
                        rotOrigin = nil
                        inertia.start(velocity: v.velocity) { dx, dy in
                            if kind.style == .ray3D {
                                yaw -= dx * 0.008
                                pitch = min(max(pitch + dy * 0.008, -1.5), 1.5)
                            } else {
                                let d = planeOffset(dx, -dy)
                                center = center.moved(dx: -d.0, dy: -d.1)
                            }
                        }
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if kind.style == .ray3D {
                            if distOrigin == nil { stopMotion(); distOrigin = dist }
                            dist = min(max((distOrigin ?? dist) / Double(v.magnification), 1e-9), 200)
                        } else {
                            if scaleOrigin == nil { stopMotion(); scaleOrigin = scale }
                            scale = min(max((scaleOrigin ?? scale) * v.magnification, kind.minScale), kind.maxScale)
                        }
                    }
                    .onEnded { _ in scaleOrigin = nil; distOrigin = nil }
            )
            // Two-finger twist: rotates the view (2D) or rolls the camera (3D).
            .simultaneousGesture(
                RotateGesture()
                    .onChanged { v in
                        if twistOrigin == nil {
                            stopMotion()
                            twistOrigin = kind.style == .ray3D ? roll : rotation
                        }
                        let angle = (twistOrigin ?? 0) + v.rotation.radians
                        if kind.style == .ray3D { roll = angle } else { rotation = angle }
                    }
                    .onEnded { _ in twistOrigin = nil }
            )
            // Tap to catch coasting.
            .simultaneousGesture(
                SpatialTapGesture(count: 1).onEnded { _ in
                    if inertia.running { inertia.stop() }
                }
            )
    }

    // MARK: Chips and controls

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .regular.tint(accent).interactive() : .regular.interactive(), in: Capsule())
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(FractalCategory.allCases) { cat in
                        chip(cat.rawValue, selected: cat == kind.category) {
                            if let first = cat.kinds.first { kind = first }
                        }
                    }
                }
            }
        }
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(kind.category.kinds) { k in
                        chip(k.rawValue, selected: k == kind) { kind = k }
                    }
                }
            }
        }
    }

    private func sliderRow(_ spec: SliderSpec, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(spec.label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Slider(value: value, in: spec.range, step: spec.step)
            Text(formatNumber(value.wrappedValue, digits: 4))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Picker("Palette", selection: $palette) {
                        ForEach(FractalPalette.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(accent)
                    if kind.supportsColoring {
                        Picker("Coloring", selection: $coloring) {
                            ForEach(FractalColoring.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(accent)
                    }
                    if !kind.variantNames.isEmpty {
                        Picker(kind.variantLabel, selection: $variant) {
                            ForEach(kind.variantNames.indices, id: \.self) { Text(kind.variantNames[$0]).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(accent)
                    }
                    Spacer()
                    Button {
                        withAnimation(.smooth) { resetView() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 34)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .accessibilityLabel("Reset view")
                }
                if kind.supportsMorph && kind != .custom && kind != .phoenix {
                    HStack {
                        Picker("c", selection: $juliaIndex) {
                            ForEach(Self.juliaPresets.indices, id: \.self) { i in
                                let c = Self.juliaPresets[i]
                                Text("c = \(formatNumber(c.re, digits: 5)) \(c.im < 0 ? "−" : "+") \(formatNumber(abs(c.im), digits: 5))i")
                                    .tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(accent)
                        Spacer()
                    }
                }
                if let spec = kind.detailSpec { sliderRow(spec, value: $detail) }
                if let spec = kind.powerSpec { sliderRow(spec, value: $power) }
                if kind.supportsMorph {
                    sliderRow(SliderSpec(label: "Morph", range: 0...1, step: 0.01, defaultValue: kind.baseMorph), value: $morph)
                    Text("Morph 0 = Mandelbrot form (c = pixel) · 1 = Julia form (c fixed)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if kind == .custom {
                    sliderRow(SliderSpec(label: "Coeff.", range: 0.2...3, step: 0.05, defaultValue: 1), value: $coef)
                    sliderRow(SliderSpec(label: "c real", range: -2...2, step: 0.01, defaultValue: -0.8), value: $customRe)
                    sliderRow(SliderSpec(label: "c imag", range: -2...2, step: 0.01, defaultValue: 0.156), value: $customIm)
                }
                HStack(spacing: 12) {
                    Text("Auto-zoom")
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Slider(value: $zoomSpeed, in: 0.25...5)
                    Text("\(formatNumber(pow(2, zoomSpeed), digits: 3))×/s")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                Text(kind.style == .ray3D
                     ? "Drag to rotate · pinch to move closer · ⌕ flies in until stopped"
                     : "Drag to pan · pinch to zoom · ⌕ zooms in on the center until stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { controlsHeight = $0 })
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(max(controlsHeight, 60), 230))
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
