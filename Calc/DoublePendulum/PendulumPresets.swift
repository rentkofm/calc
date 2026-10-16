import Foundation

/// A starting condition plus (optionally) the app settings that show it off.
/// Every claim in `note` was measured by simulating the preset: flip times and when a twin
/// offset by 10⁻⁶ rad drifts apart (> 10⁻³ rad) are for the default offset of 1e-6.
struct PendulumPreset: Identifiable {
    let name: String
    let t1: Double
    let t2: Double
    var w1 = 0.0
    var w2 = 0.0
    let note: String
    var speedExp: Double?
    var soundExp: Double?
    var soundOn: Bool?
    var trails: Bool?
    var twin: Bool?
    var twinExp: Double?
    var id: String { name }
}

struct PendulumPresetGroup: Identifiable {
    let name: String
    let icon: String
    let presets: [PendulumPreset]
    var id: String { name }
}

extension PendulumPreset {
    private static func deg(_ d: Double) -> Double { d * .pi / 180 }
    private static let root2 = 2.0.squareRoot()

    /// Total energy (J, unit masses and lengths) of a starting state.
    private static func energy(_ t1: Double, _ t2: Double, _ w1: Double, _ w2: Double) -> Double {
        w1 * w1 + 0.5 * w2 * w2 + w1 * w2 * cos(t1 - t2) - 9.81 * (2 * cos(t1) + cos(t2))
    }

    /// A rotor-style preset whose note quotes its (computed) starting energy.
    private static func highEnergy(_ name: String, _ a1: Double, _ a2: Double, _ w1: Double, _ w2: Double,
                                   _ what: String) -> PendulumPreset {
        let e = energy(deg(a1), deg(a2), w1, w2)
        return PendulumPreset(name: name, t1: deg(a1), t2: deg(a2), w1: w1, w2: w2,
                              note: String(format: "Starting energy %.0f J (a flip is possible above −9.8 J). %@", e, what))
    }

    static let groups: [PendulumPresetGroup] = [
        PendulumPresetGroup(name: "Coherent", icon: "waveform.path", presets: [
            PendulumPreset(name: "Tiny nudge", t1: deg(8), t2: 0,
                           note: "Small angles: just the two normal modes added together."),
            PendulumPreset(name: "Small swing", t1: deg(10), t2: deg(10),
                           note: "Mostly the slow mode with a little of the fast one."),
            PendulumPreset(name: "Slow mode", t1: deg(6), t2: deg(6) * root2,
                           note: "Pure slow mode: both bobs swing together, one clean frequency."),
            PendulumPreset(name: "Fast mode", t1: deg(6), t2: -deg(6) * root2,
                           note: "Pure fast mode: the bobs swing against each other, about 2.4× faster."),
            PendulumPreset(name: "Gentle lift", t1: deg(25), t2: 0,
                           note: "Bigger angles start to bend the modes, but the motion stays regular."),
            PendulumPreset(name: "Mirror pair", t1: deg(30), t2: -deg(30),
                           note: "Two bobs on opposite sides. Never flips; a twin 10⁻⁹ rad away stayed together for 100 s."),
            PendulumPreset(name: "Reach forward", t1: deg(20), t2: deg(90),
                           note: "Outer arm starts out horizontal. Regular: a twin 10⁻⁹ rad away stayed together for 100 s."),
            PendulumPreset(name: "Wide opposing swing", t1: deg(40), t2: -deg(90),
                           note: "Large, lopsided swings. Never flips; a twin 10⁻⁹ rad away stayed together for 100 s."),
            PendulumPreset(name: "Long reach", t1: deg(10), t2: -deg(110),
                           note: "Outer arm nearly horizontal on the far side. Never flips; regular for 100 s."),
            PendulumPreset(name: "Even split", t1: deg(30), t2: deg(60),
                           note: "Mid-size swings, both bobs on the same side. Never flips; regular for 100 s."),
            PendulumPreset(name: "Great island rosette", t1: deg(85.3), t2: deg(68.1),
                           note: "A regular orbit painting itself at 64×. Trails stay forever.",
                           speedExp: 6, trails: true, twin: false),
            PendulumPreset(name: "Second island rosette", t1: deg(49.5), t2: deg(98.45),
                           note: "Quasi-periodic weave at 32×.",
                           speedExp: 5, trails: true, twin: false),
            PendulumPreset(name: "Lissajous weave", t1: deg(30), t2: 0,
                           note: "Two modes beating against each other at 32×.",
                           speedExp: 5, trails: true, twin: false),
            PendulumPreset(name: "Locked rosette", t1: deg(70), t2: -deg(30),
                           note: "Energy-locked orbit drawn at 32×.",
                           speedExp: 5, trails: true, twin: false),
            PendulumPreset(name: "Gentle rotor", t1: 0, t2: 0, w1: 10, w2: 6,
                           note: "Both bobs spin over the top, regular and coherent, drawn at 16×.",
                           speedExp: 4, trails: true, twin: false),
        ]),
        PendulumPresetGroup(name: "High energy", icon: "bolt.fill", presets: [
            highEnergy("Propeller", 0, 0, 20, 20, "Both bobs spin together like a rigid propeller."),
            highEnergy("Epicycle", 0, 0, 20, 12, "The outer arm turns slower than the inner: a looping epicycle."),
            highEnergy("Slow arm", 0, 0, 30, 6, "A very fast inner arm drags a slow outer arm."),
            highEnergy("Whirling tip", 0, 0, 0, 40, "Only the outer bob starts spinning; the inner arm jiggles."),
            highEnergy("Counter-rotors", 0, 0, 6, -40, "The bobs spin in opposite directions."),
            highEnergy("Fast inner arm", 0, 0, 40, 0, "Only the inner arm starts spinning; the outer arm is dragged along."),
            highEnergy("Outward spiral", 0, 0, 12, 30, "The outer arm spins faster than the inner one."),
            highEnergy("Heavy rotor", 0, 0, 30, 30, "Two bobs spinning together at 30 rad/s."),
            highEnergy("Double speed", 0, 0, 20, 40, "The outer arm spins at twice the inner arm's speed."),
            highEnergy("Whirlwind", 0, 0, 40, 12, "The most energetic of these: speeds above 45 rad/s."),
        ]),
        PendulumPresetGroup(name: "Energy-locked (can't flip)", icon: "lock.fill", presets: [
            PendulumPreset(name: "Locked wide swing", t1: deg(60), t2: deg(80),
                           note: "2cosθ₁ + cosθ₂ > 1, so energy conservation makes a flip impossible, however long you wait."),
            PendulumPreset(name: "Locked reach", t1: deg(70), t2: -deg(30),
                           note: "Big swings, but provably never flips. Motion stays regular."),
            PendulumPreset(name: "Locked diagonal", t1: deg(45), t2: deg(45),
                           note: "Never flips; the paths are quasi-periodic."),
            PendulumPreset(name: "Locked opposite", t1: deg(50), t2: -deg(50),
                           note: "Never flips; the two bobs sound a near perfect fourth."),
        ]),
        PendulumPresetGroup(name: "Islands of stability", icon: "mappin.and.ellipse", presets: [
            PendulumPreset(name: "Great island · center", t1: deg(85.3), t2: deg(68.1),
                           note: "Deep in the biggest stable island of the fractal. Never flips (checked for 1000 s) and stays regular."),
            PendulumPreset(name: "Great island · far side", t1: deg(93.9), t2: deg(74.1),
                           note: "Same island, another orbit. Never flips (checked for 1000 s)."),
            PendulumPreset(name: "Great island · mirrored", t1: -deg(85.3), t2: -deg(68.1),
                           note: "The mirror image of the center orbit."),
            PendulumPreset(name: "Second island", t1: deg(49.5), t2: deg(98.45),
                           note: "A smaller island, surrounded by chaos. Never flips (checked for 1000 s)."),
        ]),
        PendulumPresetGroup(name: "Neat sounds", icon: "headphones", presets: [
            PendulumPreset(name: "Pure bass tone", t1: deg(6), t2: deg(6) * root2,
                           note: "A pure sine near 98 Hz at pitch 256×: the slow mode.",
                           speedExp: 0, soundExp: 8, soundOn: true),
            PendulumPreset(name: "Pure upper tone", t1: deg(6), t2: -deg(6) * root2,
                           note: "A pure sine near 231 Hz at pitch 256×: the fast mode.",
                           speedExp: 0, soundExp: 8, soundOn: true),
            PendulumPreset(name: "Minor-tenth chord", t1: deg(8), t2: 0,
                           note: "Both modes at once, about 97 and 233 Hz at pitch 256×: roughly an octave plus a minor third.",
                           speedExp: 0, soundExp: 8, soundOn: true),
            PendulumPreset(name: "Hollow island", t1: deg(85.3), t2: deg(68.1),
                           note: "Fundamental near 176 Hz at pitch 512× with strong 3rd and 5th harmonics: a clarinet-like hollow timbre.",
                           speedExp: 0, soundExp: 9, soundOn: true),
            PendulumPreset(name: "Perfect fourth", t1: deg(50), t2: -deg(50),
                           note: "Two tones at a near 4:3 ratio (about 143 and 107 Hz at pitch 256×).",
                           speedExp: 0, soundExp: 8, soundOn: true),
            PendulumPreset(name: "Rotor saw", t1: 0, t2: 0, w1: 10, w2: 10,
                           note: "Both bobs spinning: the wrapped angle is a sawtooth near 190 Hz at pitch 128×.",
                           speedExp: 0, soundExp: 7, soundOn: true),
            PendulumPreset(name: "Drifting chord", t1: deg(42.9), t2: -deg(105.9),
                           note: "Chaotic but trapped: a few wandering tones (about 180, 270 and 420 Hz at pitch 512×).",
                           speedExp: 0, soundExp: 9, soundOn: true),
            PendulumPreset(name: "Chaotic growl", t1: deg(90), t2: deg(90),
                           note: "A rough band of noise around 160–260 Hz at pitch 512×.",
                           speedExp: 0, soundExp: 9, soundOn: true),
        ]),
        PendulumPresetGroup(name: "Chaotic", icon: "tornado", presets: [
            PendulumPreset(name: "Horizontal release", t1: deg(90), t2: deg(90),
                           note: "Classic drop. First flip at ~11 s; the twin splits away at ~14 s.",
                           twin: true, twinExp: -6),
            PendulumPreset(name: "Almost upright", t1: deg(170), t2: deg(175),
                           note: "Flips almost instantly (0.3 s); the twin splits at ~4 s.",
                           twin: true, twinExp: -6),
            PendulumPreset(name: "Wild whip", t1: deg(115), t2: deg(143),
                           note: "First flip at ~4 s; the twin splits at ~4.5 s.",
                           twin: true, twinExp: -6),
            PendulumPreset(name: "Folded", t1: deg(90), t2: -deg(90),
                           note: "Flips at 1.5 s; the twin splits at ~4 s.",
                           twin: true, twinExp: -6),
            PendulumPreset(name: "Loose spinner", t1: 0, t2: 0, w1: 12, w2: -20,
                           note: "Looks like a rotor, but at only 75 J it is chaotic: the twin splits at ~7 s. Compare with High energy.",
                           twin: true, twinExp: -6),
            PendulumPreset(name: "Hard snap", t1: deg(130), t2: -deg(90),
                           note: "Flips at 1.8 s; the twin splits at ~4 s.",
                           twin: true, twinExp: -6),
        ]),
        PendulumPresetGroup(name: "Slow chaos (1×)", icon: "tortoise.fill", presets: [
            PendulumPreset(name: "Slow burn", t1: deg(80), t2: deg(50),
                           note: "Looks tame for over a minute: the twin splits at ~78 s, first flip at 153 s.",
                           speedExp: 0, twin: true, twinExp: -6),
            PendulumPreset(name: "Fraying thread", t1: deg(90), t2: deg(30),
                           note: "Gentle at first; the twin splits at ~32 s, first flip at ~6 s.",
                           speedExp: 0, twin: true, twinExp: -6),
            PendulumPreset(name: "Quiet start", t1: deg(95), t2: deg(10),
                           note: "The twin splits at ~20 s, first flip at ~8 s.",
                           speedExp: 0, twin: true, twinExp: -6),
            PendulumPreset(name: "Slow unraveling", t1: deg(90), t2: deg(60),
                           note: "The twin splits at ~23 s, first flip at ~31 s.",
                           speedExp: 0, twin: true, twinExp: -6),
            PendulumPreset(name: "Trapped chaos", t1: deg(42.9), t2: -deg(105.9),
                           note: "Never flips (checked for 1000 s) yet chaotic: the twin splits at ~55 s.",
                           speedExp: 0, twin: true, twinExp: -6),
            PendulumPreset(name: "Counter-spin", t1: 0, t2: 0, w1: 6, w2: -6,
                           note: "Bobs spinning against each other. No flip in 300 s, but the twin splits at ~70 s.",
                           speedExp: 0, twin: true, twinExp: -6),
        ]),
    ]
}
