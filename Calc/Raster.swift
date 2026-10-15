import SwiftUI

/// Momentum scrolling driven by a drag's release velocity (points/second).
final class Inertia {
    private var task: Task<Void, Never>?
    private(set) var running = false

    func stop() {
        task?.cancel()
        task = nil
        running = false
    }

    /// `onFrame` receives the distance (in points) to move this frame.
    func start(velocity: CGSize, onFrame: @escaping (_ dx: Double, _ dy: Double) -> Void) {
        stop()
        guard hypot(velocity.width, velocity.height) > 80 else { return }
        running = true
        task = Task { @MainActor [weak self] in
            var vx = Double(velocity.width), vy = Double(velocity.height)
            let dt = 1.0 / 60
            let decay = pow(0.05, dt) // keeps ~5% of its speed after one second
            while !Task.isCancelled && hypot(vx, vy) > 12 {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                onFrame(vx * dt, vy * dt)
                vx *= decay
                vy *= decay
            }
            self?.running = false
        }
    }
}

enum Raster {
    /// Size of one rendered pixel (in points) for a crisp, native-resolution image,
    /// capped so huge screens don't render more than `maxPixels`.
    static func cell(for size: CGSize, displayScale: CGFloat, maxPixels: Double = 1_000_000) -> CGFloat {
        let native = 1 / max(displayScale, 1)
        let capped = (Double(size.width * size.height) / maxPixels).squareRoot()
        return max(native, CGFloat(capped))
    }

    /// Builds an image by calling `pixel` with the point-space coordinates of each pixel centre.
    /// Rows are computed in parallel.
    static func image(size: CGSize, cell: CGFloat,
                      pixel: (_ sx: Double, _ sy: Double) -> (UInt8, UInt8, UInt8)) -> CGImage? {
        let w = max(1, Int(size.width / cell)), h = max(1, Int(size.height / cell))
        let kx = Double(size.width) / Double(w), ky = Double(size.height) / Double(h)
        var data = [UInt8](repeating: 255, count: w * h * 4)
        data.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            DispatchQueue.concurrentPerform(iterations: h) { j in
                let sy = (Double(j) + 0.5) * ky
                for i in 0..<w {
                    let (r, g, b) = pixel((Double(i) + 0.5) * kx, sy)
                    let o = (j * w + i) * 4
                    base[o] = r; base[o + 1] = g; base[o + 2] = b
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

enum ComplexRenderer {
    static func render(_ f: ComplexFn, size: CGSize, center: CGPoint, scale: CGFloat, cell: CGFloat) -> CGImage? {
        let cx = Double(center.x), cy = Double(center.y), s = Double(scale)
        let hw = Double(size.width) / 2, hh = Double(size.height) / 2
        return Raster.image(size: size, cell: cell) { sx, sy in
            color(for: f(Complex(cx + (sx - hw) / s, cy - (sy - hh) / s)))
        }
    }

    static func color(for v: Complex) -> (UInt8, UInt8, UInt8) {
        let r = v.modulus
        guard r.isFinite, !v.re.isNaN, !v.im.isNaN else { return (70, 70, 74) }
        if r == 0 { return (0, 0, 0) }
        let hue = (v.argument + .pi) / (2 * .pi) * 6 // 0...6
        let l = log2(r)
        let value = 0.55 + 0.45 * (l - floor(l))
        let sat = 0.85
        let sector = Int(hue) % 6
        let f = hue - floor(hue)
        let p = value * (1 - sat), q = value * (1 - sat * f), t = value * (1 - sat * (1 - f))
        let rgb: (Double, Double, Double)
        switch sector {
        case 0: rgb = (value, t, p)
        case 1: rgb = (q, value, p)
        case 2: rgb = (p, value, t)
        case 3: rgb = (p, q, value)
        case 4: rgb = (t, p, value)
        default: rgb = (value, p, q)
        }
        return (UInt8(rgb.0 * 255), UInt8(rgb.1 * 255), UInt8(rgb.2 * 255))
    }
}

// MARK: - Progressive rendering

/// The region of the plane an image was rendered for.
struct Viewport: Equatable {
    var cx: Double = 0
    var cy: Double = 0
    var scale: Double = 1
    var size: CGSize = .zero
}

/// Keeps the screen filled while a view is panned or zoomed:
/// a coarse frame is rendered continuously in the background (latest request wins),
/// and a native-resolution frame follows once things have been still for a moment.
@Observable
final class ProgressiveRenderer {
    private(set) var image: CGImage?
    private(set) var viewport = Viewport()

    private struct Request {
        var generation: Int
        var viewport: Viewport
        var job: (CGFloat) -> CGImage?
    }

    private var generation = 0
    private var shownGeneration = -1
    private var quickInFlight = false
    private var pending: Request?
    private var hiResTask: Task<Void, Never>?

    func clear() {
        generation += 1
        shownGeneration = generation
        pending = nil
        hiResTask?.cancel()
        image = nil
    }

    /// `job` renders the image for a given pixel size in points (smaller = sharper).
    func request(viewport: Viewport, displayScale: CGFloat, job: @escaping (_ cell: CGFloat) -> CGImage?) {
        generation += 1
        let req = Request(generation: generation, viewport: viewport, job: job)
        pending = req
        hiResTask?.cancel()
        pumpQuick()

        hiResTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
            let cell = Raster.cell(for: viewport.size, displayScale: displayScale)
            let img = await Task.detached(priority: .userInitiated) { job(cell) }.value
            guard let self, !Task.isCancelled, req.generation == self.generation else { return }
            self.show(img, viewport, req.generation)
        }
    }

    private func pumpQuick() {
        guard !quickInFlight, let req = pending else { return }
        pending = nil
        quickInFlight = true
        Task { @MainActor [weak self] in
            let img = await Task.detached(priority: .userInitiated) { req.job(3) }.value
            guard let self else { return }
            self.quickInFlight = false
            self.show(img, req.viewport, req.generation)
            self.pumpQuick() // catch up if the view moved while this frame was rendering
        }
    }

    private func show(_ img: CGImage?, _ vp: Viewport, _ gen: Int) {
        guard let img, gen >= shownGeneration else { return }
        shownGeneration = gen
        image = img
        viewport = vp
    }
}

/// Draws a rendered image, re-positioned and scaled to the *current* viewport, so panning and
/// zooming stay fluid even though the pixels are a frame or two behind.
struct ViewportImage: View {
    let image: CGImage?
    let viewport: Viewport
    let center: CGPoint
    let scale: CGFloat
    let size: CGSize

    var body: some View {
        if let image, viewport.scale > 0 {
            let k = scale / CGFloat(viewport.scale)
            if k > 1e-3, k < 500 {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: viewport.size.width * k, height: viewport.size.height * k)
                    .position(x: size.width / 2 + CGFloat(viewport.cx - Double(center.x)) * scale,
                              y: size.height / 2 - CGFloat(viewport.cy - Double(center.y)) * scale)
            }
        }
    }
}
