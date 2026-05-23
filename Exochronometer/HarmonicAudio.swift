import AVFoundation
import ExochronometerCore

struct ToneID: Hashable {
    let timeframe: TimeFrame
    let divisions: Int
    let octaves: Int
}

/// Sums sine oscillators on the audio thread. UI updates each tone's
/// amplitude per frame; the engine fills buffers continuously.
final class HarmonicAudio: ObservableObject {
    @Published private(set) var isRunning: Bool = false

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var sampleRate: Double = 44_100

    private struct Tone {
        let id: ToneID
        let frequency: Double
        var amplitude: Double = 0
        var phase: Double = 0
    }

    private var tones: [Tone] = []
    private var _volume: Double = 0.5
    private let lock = NSLock()

    var volume: Double {
        get { lock.lock(); defer { lock.unlock() }; return _volume }
        set { lock.lock(); _volume = newValue; lock.unlock() }
    }

    init(scales: [Int] = [23]) {
        let assignments = scales.flatMap { sc in
            TimeFrame.allCases
                .filter { $0 != .minute }
                .map { ToneAssignment(timeframe: $0, scale: sc) }
        }
        rebuild(assignments: assignments)
    }

    init(assignments: [ToneAssignment]) {
        rebuild(assignments: assignments)
    }

    func start() {
        guard !engine.isRunning else { return }
        configureSession()

        let format = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate

        let src = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            return self.fill(buffer: audioBufferList, frameCount: Int(frameCount))
        }
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: format)
        sourceNode = src

        do {
            try engine.start()
            DispatchQueue.main.async { self.isRunning = true }
        } catch {
            print("HarmonicAudio start failed: \(error)")
        }
    }

    func stop() {
        engine.stop()
        if let src = sourceNode {
            engine.detach(src)
            sourceNode = nil
        }
        DispatchQueue.main.async { self.isRunning = false }
    }

    func update(amplitudes: [ToneID: Double]) {
        lock.lock()
        for i in 0..<tones.count {
            tones[i].amplitude = amplitudes[tones[i].id] ?? 0
        }
        lock.unlock()
    }

    /// Rebuild the oscillator bank for a uniform scale set across all
    /// non-minute timeframes. Kept for callers that don't care about
    /// per-timeframe scaling.
    func reconfigure(scales: [Int]) {
        let assignments = scales.flatMap { sc in
            TimeFrame.allCases
                .filter { $0 != .minute }
                .map { ToneAssignment(timeframe: $0, scale: sc) }
        }
        rebuild(assignments: assignments)
    }

    /// Rebuild the oscillator bank from an explicit list of per-timeframe
    /// scale assignments. Preserves each tone's amplitude and phase across
    /// the change so audio keeps playing without a click.
    func reconfigure(assignments: [ToneAssignment]) {
        rebuild(assignments: assignments)
    }

    private func rebuild(assignments: [ToneAssignment]) {
        lock.lock()
        var prior: [ToneID: Tone] = [:]
        for t in tones { prior[t.id] = t }

        var rebuilt: [Tone] = []
        for entry in assignments {
            let tf = entry.timeframe
            let sc = entry.scale
            let factor = pow(2.0, Double(sc))
            let fundamental = (1.0 / tf.cycleDuration) * factor
            let fundId = ToneID(timeframe: tf, divisions: 1, octaves: sc)
            let oldFund = prior[fundId]
            rebuilt.append(Tone(
                id: fundId,
                frequency: fundamental,
                amplitude: oldFund?.amplitude ?? 0,
                phase: oldFund?.phase ?? 0
            ))
            for div in 3...8 {
                let id = ToneID(timeframe: tf, divisions: div, octaves: sc)
                let old = prior[id]
                rebuilt.append(Tone(
                    id: id,
                    frequency: fundamental * Double(div),
                    amplitude: old?.amplitude ?? 0,
                    phase: old?.phase ?? 0
                ))
            }
        }
        tones = rebuilt
        lock.unlock()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func fill(buffer: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(buffer)

        lock.lock()
        var localTones = tones
        let localVolume = Float(_volume)
        lock.unlock()

        let baseGain: Float = localTones.count > 40 ? 0.03 : 0.05
        let effectiveGain = baseGain * localVolume

        for frame in 0..<frameCount {
            var sample: Float = 0
            for i in 0..<localTones.count {
                let amp = localTones[i].amplitude
                if amp > 0.001 {
                    sample += Float(sin(localTones[i].phase) * amp)
                }
                localTones[i].phase += 2 * .pi * localTones[i].frequency / sampleRate
                if localTones[i].phase > 2 * .pi {
                    localTones[i].phase -= 2 * .pi
                }
            }
            let scaled = max(-1, min(1, sample * effectiveGain))
            for buffer in ablPointer {
                let bufferData = buffer.mData!.assumingMemoryBound(to: Float.self)
                bufferData[frame] = scaled
            }
        }

        // Write phases back by ID. The tone bank may have been rebuilt by
        // reconfigure() while this fill was running, so the array length
        // and ordering may not match localTones. Look up by id to stay safe.
        lock.lock()
        var phaseByID: [ToneID: Double] = [:]
        phaseByID.reserveCapacity(localTones.count)
        for t in localTones { phaseByID[t.id] = t.phase }
        for i in 0..<tones.count {
            if let phase = phaseByID[tones[i].id] {
                tones[i].phase = phase
            }
        }
        lock.unlock()

        return noErr
    }
}
