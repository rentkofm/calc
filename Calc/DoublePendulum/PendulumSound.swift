import AVFoundation

/// "Listens" to the pendulum by reinterpreting its signals as sound:
/// θ₁(t) becomes the left speaker's waveform and θ₂(t) the right speaker's.
/// The pendulum is simulated at audio rate, `timeScale` simulated seconds per real second,
/// so its slow swinging lands in the range of human hearing.
final class PendulumSound {
    // Written on the main thread, read on the audio thread (benign races on plain values).
    private var startT1 = 2.0
    private var startT2 = 2.5
    private var startW1 = 0.0
    private var startW2 = 0.0
    private var generation = 0
    private var timeScale = 256.0
    private var masterOn = false

    private let engine = AVAudioEngine()
    private var running = false

    func restart(t1: Double, t2: Double, w1: Double = 0, w2: Double = 0) {
        startT1 = t1; startT2 = t2; startW1 = w1; startW2 = w2
        generation &+= 1
    }

    func setTimeScale(_ scale: Double) { timeScale = scale }

    func start() {
        masterOn = true
        guard !running else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard rate > 0 else { return }

        var state = PendulumState(t1: startT1, t2: startT2, w1: startW1, w2: startW2)
        var seenGeneration = generation
        var master: Float = 0
        // Angles are wrapped to ±π (a spinning bob becomes a sawtooth), then DC-blocked.
        var prevX: (Float, Float) = (Self.wrap(Float(startT1)), Self.wrap(Float(startT2)))
        var prevY: (Float, Float) = (0, 0)
        let r: Float = 0.999
        // Slow peak follower so a tiny oscillation is as loud as a big one (stereo balance is kept).
        var env: Float = 0
        let envDecay = expf(-1 / (Float(rate) * 4))

        let node = AVAudioSourceNode { [weak self] _, _, frames, abl -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            if seenGeneration != self.generation {
                seenGeneration = self.generation
                state = PendulumState(t1: self.startT1, t2: self.startT2, w1: self.startW1, w2: self.startW2)
                prevX = (Self.wrap(Float(state.t1)), Self.wrap(Float(state.t2))); prevY = (0, 0)
                env = 0
            }
            let mTarget: Float = self.masterOn ? 1 : 0
            let dt = self.timeScale / rate                       // simulated seconds per audio sample
            let sub = max(1, Int((dt / min(0.008, PendulumPhysics.maxStep(for: state, limit: 0.008))).rounded(.up)))
            let h = dt / Double(sub)
            let silent = !self.masterOn && master < 0.0005

            for frame in 0..<Int(frames) {
                master += (mTarget - master) * 0.0015
                var left: Float = 0, right: Float = 0
                if !silent {
                    for _ in 0..<sub { PendulumPhysics.step(&state, dt: h) }
                    let x = (Self.wrap(Float(state.t1)), Self.wrap(Float(state.t2)))
                    prevY = (x.0 - prevX.0 + r * prevY.0, x.1 - prevX.1 + r * prevY.1)
                    prevX = x
                    env = max(max(abs(prevY.0), abs(prevY.1)), env * envDecay)
                    let gain = 0.6 * master / max(env, 0.003)   // |y| <= env, so output stays within ±0.6
                    left = prevY.0 * gain
                    right = prevY.1 * gain
                }
                if buffers.count >= 2 {
                    buffers[0].mData?.assumingMemoryBound(to: Float.self)[frame] = left
                    buffers[1].mData?.assumingMemoryBound(to: Float.self)[frame] = right
                } else if let b = buffers.first {
                    // Interleaved fallback.
                    let p = b.mData?.assumingMemoryBound(to: Float.self)
                    p?[frame * 2] = left; p?[frame * 2 + 1] = right
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2))
        do { try engine.start(); running = true } catch { running = false }
    }

    func stop() { masterOn = false }

    private static func wrap(_ a: Float) -> Float { a - 2 * .pi * roundf(a / (2 * .pi)) }
}
