import AVFoundation
import ExochronometerCore

struct ToneID: Hashable {
    let timeframe: TimeFrame
    let divisions: Int
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
    private let lock = NSLock()

    /// Build the bank from the same scaling the spectrum uses.
    init(octaves: Int = 26) {
        let factor = pow(2.0, Double(octaves))
        for tf in TimeFrame.allCases where tf != .minute {
            let fundamental = (1.0 / tf.cycleDuration) * factor
            tones.append(Tone(id: ToneID(timeframe: tf, divisions: 1), frequency: fundamental))
            for div in 3...8 {
                tones.append(Tone(id: ToneID(timeframe: tf, divisions: div), frequency: fundamental * Double(div)))
            }
        }
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

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func fill(buffer: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(buffer)

        lock.lock()
        var localTones = tones
        lock.unlock()

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
            let scaled = max(-1, min(1, sample * 0.05))
            for buffer in ablPointer {
                let bufferData = buffer.mData!.assumingMemoryBound(to: Float.self)
                bufferData[frame] = scaled
            }
        }

        lock.lock()
        for i in 0..<tones.count {
            tones[i].phase = localTones[i].phase
        }
        lock.unlock()

        return noErr
    }
}
