import SwiftUI

struct PendulumSimulatorView: View {
    let active: Bool

    @EnvironmentObject private var model: PendulumModel
    @Environment(\.appAccent) private var accent
    /// Fine-adjust step is 10^-fineExp (degrees for angles, rad/s for velocities).
    @State private var fineExp = 0
    @Environment(\.openExtras) private var openExtras

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
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
            }

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

        let showMain = model.mainVisible
        if model.permanentTrails {
            let side = 4 * scale
            let rect = CGRect(x: pivot.x - side / 2, y: pivot.y - side / 2, width: side, height: side)
            if showMain, let img = model.bitmap.image { ctx.draw(Image(decorative: img, scale: 1), in: rect) }
            for e in model.extras {
                if let img = e.bitmap.image { ctx.draw(Image(decorative: img, scale: 1), in: rect) }
            }
        } else {
            if showMain {
                if model.showTwin { drawTrail(&ctx, model.twinTrail, color: model.twinColor, pt: pt) }
                drawTrail(&ctx, model.trail, color: accent, pt: pt)
            }
            for e in model.extras { drawTrail(&ctx, e.trail, color: e.color, pt: pt) }
        }

        for e in model.extras { drawPendulum(&ctx, e.state, color: e.color, pivot: pivot, scale: scale, alpha: 1) }
        if showMain {
            if model.showTwin { drawPendulum(&ctx, model.twin, color: model.twinColor, pivot: pivot, scale: scale, alpha: 0.75) }
            drawPendulum(&ctx, model.main, color: accent, pivot: pivot, scale: scale, alpha: 1)
        }
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
                        ForEach(PendulumPreset.groups) { group in
                            Menu {
                                ForEach(group.presets) { p in Button(p.name) { model.apply(p) } }
                            } label: {
                                Label(group.name, systemImage: group.icon)
                            }
                        }
                    } label: {
                        Label("Presets", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.glass)
                }
            }

            Button {
                openExtras(.pendulumFractal)
            } label: {
                Label("Pendulum fractal", systemImage: "square.grid.3x3.fill")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glass)

            if let note = model.activeNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Label("Speed", systemImage: "speedometer").frame(width: 92, alignment: .leading)
                        Slider(value: $model.speedExp, in: 0...10, step: 1)
                            .accessibilityLabel("Playback speed")
                        Text("\(Int(model.speed))×").monospacedDigit().frame(width: 56, alignment: .trailing)
                    }

                    Toggle(isOn: $model.permanentTrails) { Label("Keep trails forever", systemImage: "scribble") }

                    Toggle(isOn: $model.showTwin) { Label("Chaos twin", systemImage: "square.on.square") }
                    if model.showTwin {
                        HStack {
                            Text("Offset").frame(width: 92, alignment: .leading)
                            Slider(value: $model.twinExp, in: -12...(-1), step: 0.5)
                                .accessibilityLabel("Twin offset exponent")
                            Text(String(format: "%.0e rad", model.twinOffset))
                                .monospacedDigit().frame(width: 84, alignment: .trailing)
                        }
                        ColorPicker("Twin color", selection: $model.twinColor, supportsOpacity: false)
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

                    Divider()

                    HStack {
                        Text("Starting position").font(.subheadline.weight(.semibold))
                        Spacer()
                        Menu {
                            Picker("Fine step", selection: $fineExp) {
                                ForEach(0...4, id: \.self) { Text(stepLabel($0)).tag($0) }
                            }
                        } label: {
                            Label("Step \(stepLabel(fineExp))", systemImage: "slider.horizontal.3")
                                .font(.subheadline)
                        }
                        .accessibilityLabel("Fine adjustment step")
                    }

                    ValueRow(name: "θ₁", unit: "°", value: degrees($model.startT1), range: -180...180,
                             step: pow(10, -Double(fineExp)), digits: 6)
                    ValueRow(name: "θ₂", unit: "°", value: degrees($model.startT2), range: -180...180,
                             step: pow(10, -Double(fineExp)), digits: 6)

                    ValueRow(name: "Energy", unit: "J", value: Binding(get: { model.startEnergy },
                                                                        set: { model.setStartEnergy($0) }),
                             range: -30...2500, step: 10 * pow(10, -Double(fineExp)), digits: 3)
                    Text(String(format: "Kinetic %.1f J + potential %.1f J. A flip becomes possible above −9.8 J; hanging at rest is −29.4 J.",
                                model.startKinetic, model.startPotential))
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !model.mainVisible {
                        Text("Angles and velocities are all 0, so no pendulum is generated.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 10) {
                        Button { model.addCurrentAsExtra() } label: {
                            Label("Add pendulum", systemImage: "plus.circle").frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.glass)
                        .disabled(!model.mainVisible)
                        Button { model.addBookmark() } label: {
                            Label("Bookmark", systemImage: "bookmark").frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.glass)
                    }

                    if !model.extras.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(model.extras) { e in
                                HStack {
                                    Circle().fill(e.color).frame(width: 12, height: 12)
                                    Text(String(format: "θ₁ %.4g°, θ₂ %.4g°", e.t1 * 180 / .pi, e.t2 * 180 / .pi))
                                        .font(.footnote).monospacedDigit()
                                    Spacer()
                                    Button { model.removeExtra(e) } label: {
                                        Image(systemName: "xmark.circle.fill").frame(width: 44, height: 32)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove pendulum")
                                }
                            }
                        }
                    }

                    if !model.bookmarks.isEmpty {
                        DisclosureGroup("Bookmarks (\(model.bookmarks.count))") {
                            VStack(spacing: 6) {
                                ForEach(model.bookmarks) { b in
                                    HStack(spacing: 4) {
                                        Button { model.load(b) } label: {
                                            Text(b.name).font(.footnote).monospacedDigit()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Load bookmark \(b.name)")
                                        Button { model.addExtra(t1: b.t1, t2: b.t2, w1: b.w1, w2: b.w2) } label: {
                                            Image(systemName: "plus.circle").frame(width: 40, height: 32)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(b.t1 == 0 && b.t2 == 0 && b.w1 == 0 && b.w2 == 0)
                                        .accessibilityLabel("Add bookmark as another pendulum")
                                        Button { model.removeBookmark(b) } label: {
                                            Image(systemName: "trash").frame(width: 40, height: 32)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Delete bookmark")
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }

                    DisclosureGroup("Initial velocity") {
                        VStack(spacing: 12) {
                            ValueRow(name: "ω₁", unit: "rad/s", value: $model.startW1, range: -20...20,
                                     step: pow(10, -Double(fineExp)), digits: 6)
                            ValueRow(name: "ω₂", unit: "rad/s", value: $model.startW2, range: -20...20,
                                     step: pow(10, -Double(fineExp)), digits: 6)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(14)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .frame(maxHeight: 230)
            .onChange(of: model.startT1) { _, _ in model.resetMain() }
            .onChange(of: model.startT2) { _, _ in model.resetMain() }
            .onChange(of: model.startW1) { _, _ in model.resetMain() }
            .onChange(of: model.startW2) { _, _ in model.resetMain() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func stepLabel(_ exp: Int) -> String { exp == 0 ? "1" : "0." + String(repeating: "0", count: exp - 1) + "1" }

    /// Radians in the model, degrees on screen.
    private func degrees(_ radians: Binding<Double>) -> Binding<Double> {
        Binding(get: { radians.wrappedValue * 180 / .pi },
                set: { radians.wrappedValue = min(max($0, -180), 180) * .pi / 180 })
    }
}

/// A slider with a typed value and −/+ nudge buttons, so values can be set precisely.
private struct ValueRow: View {
    let name: String
    let unit: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let digits: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(name).font(.body.weight(.semibold))
                Spacer()
                nudge("minus", -step)
                NumberEntry(value: clamped, digits: digits)
                    .accessibilityLabel("\(name) in \(unit)")
                Text(unit).font(.footnote).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                nudge("plus", step)
            }
            Slider(value: clamped, in: range)
                .accessibilityLabel(name)
        }
    }

    private var clamped: Binding<Double> {
        Binding(get: { value }, set: { value = min(max($0, range.lowerBound), range.upperBound) })
    }

    private func nudge(_ symbol: String, _ delta: Double) -> some View {
        Button {
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: symbol).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? "Decrease \(name)" : "Increase \(name)")
    }
}

/// Text entry that accepts decimals (. or ,), negatives and 0 while typing, and commits each valid number as it changes.
private struct NumberEntry: View {
    @Binding var value: Double
    let digits: Int
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 96)
            .focused($focused)
            .onAppear { text = format(value) }
            .onChange(of: text) { _, new in
                if let v = Double(new.replacingOccurrences(of: ",", with: ".")), v != value { value = v }
            }
            .onChange(of: value) { _, new in if !focused { text = format(new) } }
            .onChange(of: focused) { _, f in if !f { text = format(value) } }
    }

    private func format(_ v: Double) -> String {
        var s = String(format: "%.\(digits)f", v)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s == "-0" ? "0" : s
    }
}
