import SwiftUI
import UIKit

/// The classic double-pendulum "flip time" fractal: every pixel is a pair of starting
/// angles (θ₁ horizontally, θ₂ vertically), coloured by how long until a bob first flips over.
struct PendulumFractalView: View {
    @EnvironmentObject private var model: PendulumModel
    @Environment(\.appAccent) private var accent
    @State private var image: CGImage?
    @State private var resolution = 160
    @State private var duration = 10.0
    @State private var isRendering = false
    @State private var renderID = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: side, height: side)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .topLeading) { axisLabel("θ₂ ↑") }
                            .overlay(alignment: .bottomTrailing) { axisLabel("θ₁ →") }
                            .gesture(
                                SpatialTapGesture().onEnded { tap in
                                    let t1 = Double(tap.location.x / side) * 2 * .pi - .pi
                                    let t2 = Double(1 - tap.location.y / side) * 2 * .pi - .pi
                                    model.launch(t1: t1, t2: t2)
                                }
                            )
                            .accessibilityLabel("Fractal of double pendulum flip times. Tap to simulate that starting position.")
                    }
                    if isRendering { ProgressView().controlSize(.large) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal)

            Text("Tap anywhere to watch that starting position swing. Dark = never flips.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            VStack(spacing: 8) {
                Picker("Resolution", selection: $resolution) {
                    Text("Fast").tag(96); Text("Normal").tag(160); Text("Fine").tag(256)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Simulate").font(.subheadline)
                    Slider(value: $duration, in: 2...30, step: 1)
                    Text("\(Int(duration)) s").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
                Button { render() } label: {
                    Label("Render", systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.glassProminent).disabled(isRendering)
            }
            .padding(.horizontal).padding(.bottom, 8)
        }
        .task(id: visibleNow) { if visibleNow && image == nil { render() } }
        .onChange(of: resolution) { _, _ in refresh() }
        .onChange(of: scheme) { _, _ in refresh() }
        .onChange(of: accent) { _, _ in refresh() }
    }

    private func axisLabel(_ text: String) -> some View {
        Text(text).font(.caption2.bold()).padding(4)
            .background(.ultraThinMaterial, in: Capsule()).padding(6)
            .accessibilityHidden(true)
    }

    private var visibleNow: Bool { model.hubActive && model.mode == .fractal }

    /// Re-render now if on screen; otherwise mark stale so it renders when next shown.
    private func refresh() {
        if visibleNow { render() } else { renderID += 1; image = nil; isRendering = false }
    }

    private func render() {
        renderID += 1
        let id = renderID
        let n = resolution, limit = duration
        let accent = UIColor(accent)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        accent.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let hue = Double(h)
        let dark = UIColor.secondarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
        var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0
        dark.getRed(&dr, green: &dg, blue: &db, alpha: &a)
        let bg = (UInt8(dr * 255), UInt8(dg * 255), UInt8(db * 255))

        isRendering = true
        DispatchQueue.global(qos: .userInitiated).async {
            var pixels = [UInt8](repeating: 255, count: n * n * 4)
            pixels.withUnsafeMutableBufferPointer { buf in
                let base = buf.baseAddress!
                DispatchQueue.concurrentPerform(iterations: n) { row in
                    // Row 0 is the top of the image = largest θ₂.
                    let t2 = (1 - (Double(row) + 0.5) / Double(n)) * 2 * .pi - .pi
                    for col in 0..<n {
                        let t1 = (Double(col) + 0.5) / Double(n) * 2 * .pi - .pi
                        let o = (row * n + col) * 4
                        if let t = PendulumPhysics.flipTime(t1: t1, t2: t2, limit: limit) {
                            // Log-scale so the quick flips and slow flips both show detail.
                            let x = min(1, log(1 + t) / log(1 + limit))
                            let (r, g, bl) = Self.hsb(hue: hue + 0.55 * x, sat: 0.75, bri: 1 - 0.35 * x)
                            base[o] = r; base[o + 1] = g; base[o + 2] = bl
                        } else {
                            base[o] = bg.0; base[o + 1] = bg.1; base[o + 2] = bg.2
                        }
                        base[o + 3] = 255
                    }
                }
            }
            let cg = pixels.withUnsafeBytes { raw -> CGImage? in
                guard let provider = CGDataProvider(data: Data(raw) as CFData) else { return nil }
                return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: false,
                               intent: .defaultIntent)
            }
            DispatchQueue.main.async {
                guard id == renderID else { return }
                image = cg
                isRendering = false
            }
        }
    }

    private static func hsb(hue: Double, sat: Double, bri: Double) -> (UInt8, UInt8, UInt8) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hue: CGFloat(hue.truncatingRemainder(dividingBy: 1)), saturation: CGFloat(sat),
                brightness: CGFloat(bri), alpha: 1).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }
}
