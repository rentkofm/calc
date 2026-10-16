import SwiftUI

struct PendulumSimulatorView: View {
    let active: Bool

    @EnvironmentObject private var model: PendulumModel
    @Environment(\.appAccent) private var accent

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.animation(paused: !model.isPlaying || !active)) { timeline in
                Canvas { ctx, size in
                    model.advance(to: timeline.date, accent: accent)
                    draw(&ctx, size: size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28,
                                                              style: .continuous))
            .ignoresSafeArea(edges: .top)
            .accessibilityLabel("Double pendulum simulation")

            controls
        }
        .onChange(of: model.isPlaying) { _, playing in if !playing { model.pause() } }
        .onChange(of: active) { _, _ in model.pause() }
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width, size.height) / 2 * 0.46
        let pivot = CGPoint(x: size.width / 2, y: size.height / 2)
        func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: pivot.x + p.x * scale, y: pivot.y + p.y * scale) }

        if model.permanentTrails {
            if let img = model.bitmap.image {
                let side = 4 * scale
                ctx.draw(Image(decorative: img, scale: 1),
                         in: CGRect(x: pivot.x - side / 2, y: pivot.y - side / 2, width: side, height: side))
            }
        } else {
            if model.showTwin { drawTrail(&ctx, model.twinTrail, color: .secondary, pt: pt) }
            drawTrail(&ctx, model.trail, color: accent, pt: pt)
        }

        if model.showTwin { drawPendulum(&ctx, model.twin, color: .secondary, pivot: pivot, scale: scale, alpha: 0.7) }
        drawPendulum(&ctx, model.main, color: accent, pivot: pivot, scale: scale, alpha: 1)
    }

    private func drawTrail(_ ctx: inout GraphicsContext, _ trail: [CGPoint], color: Color, pt: (CGPoint) -> CGPoint) {
        guard trail.count > 1 else { return }
        let chunk = 25
        var i = 0
        while i < trail.count - 1 {
            let end = min(i + chunk, trail.count - 1)
            var path = Path()
            path.move(to: pt(trail[i]))
            for j in (i + 1)...end { path.addLine(to: pt(trail[j])) }
            let fade = Double(end) / Double(trail.count)
            ctx.stroke(path, with: .color(color.opacity(fade * fade)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            i = end
        }
    }

    private func drawPendulum(_ ctx: inout GraphicsContext, _ s: PendulumState, color: Color,
                              pivot: CGPoint, scale: CGFloat, alpha: Double) {
        let b1 = CGPoint(x: pivot.x + sin(s.t1) * scale, y: pivot.y + cos(s.t1) * scale)
        let b2 = CGPoint(x: b1.x + sin(s.t2) * scale, y: b1.y + cos(s.t2) * scale)
        var rods = Path()
        rods.move(to: pivot); rods.addLine(to: b1); rods.addLine(to: b2)
        ctx.stroke(rods, with: .color(color.opacity(alpha)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        for p in [b1, b2] {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)),
                     with: .color(color.opacity(alpha)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: pivot.x - 4, y: pivot.y - 4, width: 8, height: 8)),
                 with: .color(.primary))
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 10) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        model.isPlaying.toggle()
                    } label: {
                        Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        model.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.glass)

                    Menu {
                        Section("Regular (non-chaotic)") {
                            ForEach(PendulumPreset.regular) { p in Button(p.name) { model.apply(p) } }
                        }
                        Section("Chaotic") {
                            ForEach(PendulumPreset.chaotic) { p in Button(p.name) { model.apply(p) } }
                        }
                    } label: {
                        Label("Presets", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.glass)
                }
            }

            ScrollView {
                VStack(spacing: 10) {
                    HStack {
                        Label("Speed", systemImage: "speedometer").frame(width: 92, alignment: .leading)
                        Slider(value: $model.speedExp, in: 0...10, step: 1)
                            .accessibilityLabel("Playback speed")
                        Text("\(Int(model.speed))×").monospacedDigit().frame(width: 56, alignment: .trailing)
                    }

                    Toggle(isOn: $model.permanentTrails) { Label("Keep trails forever", systemImage: "scribble") }
                    Toggle(isOn: $model.showTwin) {
                        Label("Chaos twin (0.000001 rad apart)", systemImage: "square.on.square")
                    }

                    Toggle(isOn: $model.soundOn) { Label("Listen (θ₁ left, θ₂ right)", systemImage: "headphones") }
                    if model.soundOn {
                        HStack {
                            Label("Pitch", systemImage: "waveform").frame(width: 92, alignment: .leading)
                            Slider(value: $model.soundExp, in: 5...11, step: 1)
                                .accessibilityLabel("Sound time scale")
                            Text("\(Int(pow(2, model.soundExp.rounded())))×").monospacedDigit()
                                .frame(width: 56, alignment: .trailing)
                        }
                    }

                    angleSlider("θ₁", value: $model.startT1)
                    angleSlider("θ₂", value: $model.startT2)
                }
                .padding(14)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .frame(maxHeight: 190)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func angleSlider(_ name: String, value: Binding<Double>) -> some View {
        HStack {
            Text(name).frame(width: 28, alignment: .leading)
            Slider(value: value, in: -Double.pi...Double.pi)
                .accessibilityLabel("Starting angle \(name)")
            Text(String(format: "%.0f°", value.wrappedValue * 180 / .pi))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
        .onChange(of: value.wrappedValue) { _, _ in model.reset() }
    }
}
