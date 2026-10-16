import AVFoundation

/// "Listens" to the pendulum by reinterpreting its signals as sound:
/// θ₁(t) becomes the left speaker's waveform and θ₂(t) the right speaker's.
/// The pendulum is simulated at audio rate, `timeScale` simulated seconds per real second,
/// so its slow swinging lands in the range of human hearing.
final class PendulumSound {
    // Written on the main thread, read on the audio thread (benign races on plain values).
    private var startT1 = 2.0
    private var startT2 = 2.5
    private var generation = 0
    private var timeScale = 256.0
    private var masterOn = false

    private let engine = AVAudioEngine()
    private var running = false

    func restart(t1: Double, t2: Double) {
        startT1 = t1; startT2 = t2
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

        var state = PendulumState(t1: startT1, t2: startT2)
        var seenGeneration = generation
        var master: Float = 0
        // One-pole DC blockers: the raw angle can drift (e.g. when the pendulum spins over the top).
        var prevX: (Float, Float) = (0, 0)
        var prevY: (Float, Float) = (0, 0)
        let r: Float = 0.999

        let node = AVAudioSourceNode { [weak self] _, _, frames, abl -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            if seenGeneration != self.generation {
                seenGeneration = self.generation
                state = PendulumState(t1: self.startT1, t2: self.startT2)
                prevX = (Float(state.t1), Float(state.t2)); prevY = (0, 0)
            }
            let mTarget: Float = self.masterOn ? 1 : 0
            let dt = self.timeScale / rate                       // simulated seconds per audio sample
            let sub = max(1, Int((dt / 0.008).rounded(.up)))
            let h = dt / Double(sub)
            let silent = !self.masterOn && master < 0.0005

            for frame in 0..<Int(frames) {
                master += (mTarget - master) * 0.0015
                var left: Float = 0, right: Float = 0
                if !silent {
                    for _ in 0..<sub { PendulumPhysics.step(&state, dt: h) }
                    let x = (Float(state.t1), Float(state.t2))
                    prevY = (x.0 - prevX.0 + r * prevY.0, x.1 - prevX.1 + r * prevY.1)
                    prevX = x
                    left = tanhf(0.5 * prevY.0) * master * 0.6
                    right = tanhf(0.5 * prevY.1) * master * 0.6
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
}
