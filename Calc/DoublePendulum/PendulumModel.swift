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

/// An additional pendulum running alongside the main one, with its own start, path and colour.
final class PendulumInstance: Identifiable {
    let id = UUID()
    let t1: Double, t2: Double, w1: Double, w2: Double
    let color: Color
    var state: PendulumState
    var trail: [CGPoint] = []
    let bitmap = PendulumTrailBitmap()

    init(t1: Double, t2: Double, w1: Double, w2: Double, color: Color) {
        self.t1 = t1; self.t2 = t2; self.w1 = w1; self.w2 = w2; self.color = color
        state = PendulumState(t1: t1, t2: t2, w1: w1, w2: w2)
    }

    func reset() {
        state = PendulumState(t1: t1, t2: t2, w1: w1, w2: w2)
        trail.removeAll(); bitmap.clear()
    }
}

/// A saved starting condition.
struct PendulumBookmark: Codable, Identifiable {
    var id = UUID()
    var name: String
    var t1: Double, t2: Double, w1: Double, w2: Double
}

/// Shared state: the live pendulum(s), the sound engine and the starting angles.
final class PendulumModel: ObservableObject {

    /// Bumped when the fractal asks to simulate a point, so the Extras tab can switch to the simulator.
    @Published var launchTick = 0
    @Published var isPlaying = true
    @Published var showTwin = false {
        didSet { if !showTwin { twinTrail.removeAll(); bitmap.dropTwin() } else { twin = main; twin.t1 += twinOffset } }
    }
    @Published var permanentTrails = false {
        didSet {
            trail.removeAll(); twinTrail.removeAll(); bitmap.clear()
            for e in extras { e.trail.removeAll(); e.bitmap.clear() }
        }
    }
    /// Extra pendulums running alongside the main one.
    @Published private(set) var extras: [PendulumInstance] = []
    @Published private(set) var bookmarks: [PendulumBookmark] = [] {
        didSet { saveBookmarks() }
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
    /// Starting angular velocities (rad/s).
    @Published var startW1 = 0.0
    @Published var startW2 = 0.0
    /// The chaos twin starts 10^twinExp radians away in θ₁.
    @Published var twinExp = -6.0 { didSet { resetMain() } }
    @Published var twinColor: Color {
        didSet { UserDefaults.standard.set(twinColor.hex, forKey: "pendulumTwinColor") }
    }
    @Published private(set) var activePreset: PendulumPreset?

    var twinOffset: Double { pow(10, twinExp) }

    /// Hanging straight down at rest (both angles and both velocities 0) means there is nothing to generate,
    /// so no main pendulum is drawn.
    var mainVisible: Bool { !(startT1 == 0 && startT2 == 0 && startW1 == 0 && startW2 == 0) }
    private static let extraPalette = ["FF9F0A", "30D158", "FF375F", "BF5AF2", "64D2FF"]

    // Energy of the starting state (unit masses and rod lengths, so joules ≈ kg·m²/s²).
    var startKinetic: Double { startW1 * startW1 + 0.5 * startW2 * startW2 + startW1 * startW2 * cos(startT1 - startT2) }
    var startPotential: Double { -PendulumPhysics.gravity * (2 * cos(startT1) + cos(startT2)) }
    var startEnergy: Double { startKinetic + startPotential }

    /// Sets the total starting energy by scaling the starting velocities (kinetic energy can't go below zero).
    func setStartEnergy(_ e: Double) {
        let target = max(0, e - startPotential)
        let cur = startKinetic
        if cur > 1e-12 {
            let k = (target / cur).squareRoot()
            startW1 *= k; startW2 *= k
        } else {
            let base = 1.5 + cos(startT1 - startT2)        // kinetic energy of ω₁ = ω₂ = 1
            let k = (target / base).squareRoot()
            startW1 = k; startW2 = k
        }
    }

    func stopSound() { if soundOn { soundOn = false } }

    /// The active preset's note, while the start still matches the preset.
    var activeNote: String? {
        guard let p = activePreset, p.t1 == startT1, p.t2 == startT2, p.w1 == startW1, p.w2 == startW2 else { return nil }
        return "\(p.name): \(p.note)"
    }

    var speed: Double { pow(2, speedExp.rounded()) }

    // Mutated every frame by the renderer; deliberately not @Published.
    private(set) var main = PendulumState(t1: 2.0, t2: 2.5)
    private(set) var twin = PendulumState(t1: 2.0 + 1e-6, t2: 2.5)
    private(set) var trail: [CGPoint] = []   // bob 2 positions in rod units
    private(set) var twinTrail: [CGPoint] = []
    /// (θ₁, θ₂) history of the main pendulum, each wrapped to −π…π, for the angle graph.
    private(set) var angleTrail: [CGPoint] = []
    let bitmap = PendulumTrailBitmap()
    private var lastDate: Date?
    private let sound = PendulumSound()
    static let maxTrail = 800
    static let maxAngleTrail = 2500

    init() {
        twinColor = Color(hex: UserDefaults.standard.string(forKey: "pendulumTwinColor") ?? "8E8E93")
        if let data = UserDefaults.standard.data(forKey: "pendulumBookmarks"),
           let saved = try? JSONDecoder().decode([PendulumBookmark].self, from: data) {
            bookmarks = saved
        }
        resetMain()
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) { UserDefaults.standard.set(data, forKey: "pendulumBookmarks") }
    }

    /// Restarts every pendulum from its starting state.
    func reset() {
        resetMain()
        for e in extras { e.reset() }
    }

    // MARK: Extra pendulums and bookmarks

    /// Adds another pendulum; ignored when it would just hang at rest.
    func addExtra(t1: Double, t2: Double, w1: Double, w2: Double) {
        guard !(t1 == 0 && t2 == 0 && w1 == 0 && w2 == 0) else { return }
        let hex = Self.extraPalette[extras.count % Self.extraPalette.count]
        extras.append(PendulumInstance(t1: t1, t2: t2, w1: w1, w2: w2, color: Color(hex: hex)))
        isPlaying = true
    }

    func addCurrentAsExtra() { addExtra(t1: startT1, t2: startT2, w1: startW1, w2: startW2) }
    func removeExtra(_ e: PendulumInstance) { extras.removeAll { $0.id == e.id } }
    func clearExtras() { extras.removeAll() }

    func addBookmark() {
        let d = 180 / Double.pi
        let name = String(format: "θ₁ %.4g°, θ₂ %.4g°", startT1 * d, startT2 * d)
        bookmarks.append(PendulumBookmark(name: name, t1: startT1, t2: startT2, w1: startW1, w2: startW2))
    }

    func removeBookmark(_ b: PendulumBookmark) { bookmarks.removeAll { $0.id == b.id } }

    func load(_ b: PendulumBookmark) {
        startT1 = b.t1; startT2 = b.t2; startW1 = b.w1; startW2 = b.w2
        activePreset = nil
        resetMain()
        isPlaying = true
    }

    func resetMain() {
        main = PendulumState(t1: startT1, t2: startT2, w1: startW1, w2: startW2)
        twin = PendulumState(t1: startT1 + twinOffset, t2: startT2, w1: startW1, w2: startW2)
        trail.removeAll(); twinTrail.removeAll(); angleTrail.removeAll(); bitmap.clear()
        lastDate = nil
        sound.restart(t1: startT1, t2: startT2, w1: startW1, w2: startW2)
    }

    func apply(_ p: PendulumPreset) {
        startT1 = p.t1; startT2 = p.t2; startW1 = p.w1; startW2 = p.w2
        if let v = p.speedExp { speedExp = v }
        if let v = p.soundExp { soundExp = v }
        if let v = p.trails { permanentTrails = v }
        if let v = p.twin { showTwin = v }
        if let v = p.twinExp { twinExp = v }
        activePreset = p
        resetMain()
        if let on = p.soundOn { soundOn = on }
        isPlaying = true
    }

    func launch(t1: Double, t2: Double, w1: Double = 0, w2: Double = 0) {
        startT1 = t1; startT2 = t2; startW1 = w1; startW2 = w2
        activePreset = nil
        resetMain()
        isPlaying = true
        launchTick += 1
    }

    func advance(to date: Date, accent: Color) {
        defer { lastDate = date }
        guard isPlaying, let last = lastDate else { return }
        let frame = min(date.timeIntervalSince(last), 1.0 / 20) * speed
        // Spinning bobs need smaller steps to stay accurate.
        let showMain = mainVisible
        var dtMax = 0.004
        if showMain {
            dtMax = min(dtMax, PendulumPhysics.maxStep(for: main))
            if showTwin { dtMax = min(dtMax, PendulumPhysics.maxStep(for: twin)) }
        }
        for e in extras { dtMax = min(dtMax, PendulumPhysics.maxStep(for: e.state)) }
        let steps = min(20000, max(1, Int((frame / dtMax).rounded(.up))))
        let dt = frame / Double(steps)
        // Record a handful of path points per frame, more at high speed so fast paths stay smooth.
        let points = min(steps, max(1, Int(speed.squareRoot() * 2)))
        let mainColor = UIColor(accent).cgColor
        let twinCG = UIColor(twinColor).cgColor

        for i in 0..<steps {
            if showMain {
                PendulumPhysics.step(&main, dt: dt)
                if showTwin { PendulumPhysics.step(&twin, dt: dt) }
            }
            for e in extras { PendulumPhysics.step(&e.state, dt: dt) }
            guard (i + 1) * points / steps > i * points / steps else { continue }
            if showMain {
                let m = Self.tip(main), t = Self.tip(twin)
                angleTrail.append(CGPoint(x: Self.wrap(main.t1), y: Self.wrap(main.t2)))
                if permanentTrails {
                    bitmap.addMain(m, color: mainColor)
                    if showTwin { bitmap.addTwin(t, color: twinCG) }
                } else {
                    trail.append(m)
                    if showTwin { twinTrail.append(t) }
                }
            }
            for e in extras {
                let p = Self.tip(e.state)
                if permanentTrails { e.bitmap.addMain(p, color: UIColor(e.color).cgColor) } else { e.trail.append(p) }
            }
        }
        for e in extras where e.trail.count > Self.maxTrail { e.trail.removeFirst(e.trail.count - Self.maxTrail) }
        if angleTrail.count > Self.maxAngleTrail { angleTrail.removeFirst(angleTrail.count - Self.maxAngleTrail) }
        if trail.count > Self.maxTrail { trail.removeFirst(trail.count - Self.maxTrail) }
        if twinTrail.count > Self.maxTrail { twinTrail.removeFirst(twinTrail.count - Self.maxTrail) }
    }

    func pause() { lastDate = nil }

    static func wrap(_ a: Double) -> Double { atan2(sin(a), cos(a)) }

    static func tip(_ s: PendulumState) -> CGPoint {
        CGPoint(x: sin(s.t1) + sin(s.t2), y: cos(s.t1) + cos(s.t2))
    }
}
