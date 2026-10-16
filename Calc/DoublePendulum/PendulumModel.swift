import SwiftUI
import UIKit

/// Offscreen bitmap that accumulates the pendulum's path so trails can last forever
/// without redrawing an ever-growing list of points. World space is [-2, 2] on both axes.
final class PendulumTrailBitmap {
    private static let size = 1024
    private var ctx: CGContext?
    private var cached: CGImage?
    private var lastMain: CGPoint?
    private var lastTwin: CGPoint?

    init() { makeContext() }

    private func makeContext() {
        let n = Self.size
        ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.translateBy(x: 0, y: CGFloat(n)); ctx?.scaleBy(x: 1, y: -1)   // y-down like the screen
        ctx?.setLineCap(.round); ctx?.setLineWidth(3)
    }

    func clear() {
        ctx?.clear(CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
        lastMain = nil; lastTwin = nil; cached = nil
    }

    private func px(_ p: CGPoint) -> CGPoint {
        let n = CGFloat(Self.size)
        return CGPoint(x: (p.x + 2) / 4 * n, y: (p.y + 2) / 4 * n)
    }

    func addMain(_ p: CGPoint, color: CGColor) { add(p, last: &lastMain, color: color) }
    func addTwin(_ p: CGPoint, color: CGColor) { add(p, last: &lastTwin, color: color) }
    func dropTwin() { lastTwin = nil }

    private func add(_ p: CGPoint, last: inout CGPoint?, color: CGColor) {
        if let l = last, let ctx {
            ctx.setStrokeColor(color)
            ctx.move(to: px(l)); ctx.addLine(to: px(p)); ctx.strokePath()
            cached = nil
        }
        last = p
    }

    var image: CGImage? {
        if cached == nil { cached = ctx?.makeImage() }
        return cached
    }
}

/// Shared state: the live pendulum(s), the sound engine and the starting angles.
final class PendulumModel: ObservableObject {

    /// Bumped when the fractal asks to simulate a point, so the Extras tab can switch to the simulator.
    @Published var launchTick = 0
    @Published var isPlaying = true
    @Published var showTwin = true {
        didSet { if !showTwin { twinTrail.removeAll(); bitmap.dropTwin() } else { twin = main; twin.t1 += 1e-6 } }
    }
    @Published var permanentTrails = false {
        didSet { trail.removeAll(); twinTrail.removeAll(); bitmap.clear() }
    }
    /// Playback speed is 2^speedExp (1× … 1024×).
    @Published var speedExp = 0.0
    @Published var soundOn = false {
        didSet { soundOn ? sound.start() : sound.stop() }
    }
    /// Sound time scale is 2^soundExp simulated seconds per real second.
    @Published var soundExp = 8.0 { didSet { sound.setTimeScale(pow(2, soundExp.rounded())) } }
    /// Starting angles (radians) used by Reset; set by the sliders, presets or by tapping the fractal.
    @Published var startT1 = 2.0
    @Published var startT2 = 2.5

    var speed: Double { pow(2, speedExp.rounded()) }

    // Mutated every frame by the renderer; deliberately not @Published.
    private(set) var main = PendulumState(t1: 2.0, t2: 2.5)
    private(set) var twin = PendulumState(t1: 2.0 + 1e-6, t2: 2.5)
    private(set) var trail: [CGPoint] = []   // bob 2 positions in rod units
    private(set) var twinTrail: [CGPoint] = []
    let bitmap = PendulumTrailBitmap()
    private var lastDate: Date?
    private let sound = PendulumSound()
    static let maxTrail = 800

    init() { reset() }

    func reset() {
        main = PendulumState(t1: startT1, t2: startT2)
        twin = PendulumState(t1: startT1 + 1e-6, t2: startT2)
        trail.removeAll(); twinTrail.removeAll(); bitmap.clear()
        lastDate = nil
        sound.restart(t1: startT1, t2: startT2)
    }

    func apply(_ preset: PendulumPreset) {
        startT1 = preset.t1; startT2 = preset.t2
        reset()
        isPlaying = true
    }

    func launch(t1: Double, t2: Double) {
        startT1 = t1; startT2 = t2
        reset()
        isPlaying = true
        launchTick += 1
    }

    func advance(to date: Date, accent: Color) {
        defer { lastDate = date }
        guard isPlaying, let last = lastDate else { return }
        let frame = min(date.timeIntervalSince(last), 1.0 / 20) * speed
        let steps = max(1, Int((frame / 0.004).rounded(.up)))
        let dt = frame / Double(steps)
        // Record a handful of path points per frame, more at high speed so fast paths stay smooth.
        let points = min(steps, max(1, Int(speed.squareRoot() * 2)))
        let mainColor = UIColor(accent).cgColor
        let twinColor = UIColor.systemGray.cgColor

        for i in 0..<steps {
            PendulumPhysics.step(&main, dt: dt)
            if showTwin { PendulumPhysics.step(&twin, dt: dt) }
            guard (i + 1) * points / steps > i * points / steps else { continue }
            let m = Self.tip(main), t = Self.tip(twin)
            if permanentTrails {
                bitmap.addMain(m, color: mainColor)
                if showTwin { bitmap.addTwin(t, color: twinColor) }
            } else {
                trail.append(m)
                if showTwin { twinTrail.append(t) }
            }
        }
        if trail.count > Self.maxTrail { trail.removeFirst(trail.count - Self.maxTrail) }
        if twinTrail.count > Self.maxTrail { twinTrail.removeFirst(twinTrail.count - Self.maxTrail) }
    }

    func pause() { lastDate = nil }

    static func tip(_ s: PendulumState) -> CGPoint {
        CGPoint(x: sin(s.t1) + sin(s.t2), y: cos(s.t1) + cos(s.t2))
    }
}
