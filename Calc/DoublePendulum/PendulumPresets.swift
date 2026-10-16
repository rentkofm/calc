import Foundation

struct PendulumPreset: Identifiable {
    let name: String
    let t1: Double
    let t2: Double
    let chaotic: Bool
    var id: String { name }

    private static func deg(_ d: Double) -> Double { d * .pi / 180 }

    /// Small angles, or the two normal modes: motion stays regular and periodic.
    static let regular: [PendulumPreset] = [
        PendulumPreset(name: "Small swing", t1: deg(10), t2: deg(10), chaotic: false),
        PendulumPreset(name: "Slow mode (in phase)", t1: deg(6), t2: deg(6) * 2.0.squareRoot(), chaotic: false),
        PendulumPreset(name: "Fast mode (opposite)", t1: deg(6), t2: -deg(6) * 2.0.squareRoot(), chaotic: false),
        PendulumPreset(name: "Gentle lift", t1: deg(25), t2: 0, chaotic: false),
    ]

    /// Big angles: tiny changes blow up exponentially.
    static let chaotic: [PendulumPreset] = [
        PendulumPreset(name: "Horizontal release", t1: deg(90), t2: deg(90), chaotic: true),
        PendulumPreset(name: "Almost upright", t1: deg(170), t2: deg(175), chaotic: true),
        PendulumPreset(name: "Wild whip", t1: deg(115), t2: deg(143), chaotic: true),
        PendulumPreset(name: "Folded", t1: deg(90), t2: -deg(90), chaotic: true),
    ]
}
