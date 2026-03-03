import AVFoundation
import Combine

/// Generative ambient audio engine — Brian Eno's "Music for Airports" philosophy:
/// simple tones overlapping at incommensurate intervals, creating an ever-shifting
/// soundscape that never repeats. Warm sine-ish waves through cathedral reverb.
///
/// Each scene maps to one of six moods. Moods define the scale, pacing, brightness,
/// and reverb depth. Notes are scheduled at random intervals from pentatonic scales,
/// with long attack and release envelopes. The result is a gentle, drifting wash of
/// tones — present enough to be felt, quiet enough to disappear into.
final class AmbientAudioEngine: ObservableObject {

    @Published private(set) var isPlaying = false
    @Published var isMuted = false {
        didSet {
            engine?.mainMixerNode.outputVolume = isMuted ? 0 : (currentMood?.masterVolume ?? 0)
        }
    }

    // MARK: - Mood

    struct Mood: Equatable {
        let name: String
        let rootMidi: Int          // MIDI note for the scale root
        let intervals: [Int]       // scale degrees as semitone offsets
        let octaves: [Int]         // relative octave choices (weighted by repetition)
        let noteSpacing: ClosedRange<Double>  // seconds between new notes
        let attackTime: Double     // seconds to fade in
        let releaseTime: Double    // seconds to fade out
        let brightness: Double     // harmonic content 0–1
        let reverbWet: Float       // reverb wet/dry 0–100
        let masterVolume: Float    // output volume 0–1

        static func == (lhs: Mood, rhs: Mood) -> Bool { lhs.name == rhs.name }
    }

    /// Six moods covering the emotional range of all scenes.
    /// Pentatonic scales only — no dissonance, ever.
    static let moods: [String: Mood] = [
        // Amber comfort — home, warmth, safety
        "warm": Mood(
            name: "warm", rootMidi: 60,
            intervals: [0, 2, 4, 7, 9],          // C major pentatonic
            octaves: [-1, 0, 0, 1],
            noteSpacing: 3.5...9.0,
            attackTime: 1.2, releaseTime: 5.0,
            brightness: 0.25, reverbWet: 75, masterVolume: 0.14
        ),
        // Rain, ocean, night — cooler, more spacious
        "cool": Mood(
            name: "cool", rootMidi: 62,
            intervals: [0, 3, 5, 7, 10],         // D minor pentatonic
            octaves: [-1, 0, 0, 1],
            noteSpacing: 4.5...13.0,
            attackTime: 1.8, releaseTime: 7.0,
            brightness: 0.12, reverbWet: 88, masterVolume: 0.11
        ),
        // Stars, nebulae, vast emptiness
        "cosmic": Mood(
            name: "cosmic", rootMidi: 63,
            intervals: [0, 2, 4, 7, 9],          // Eb major pentatonic
            octaves: [-1, 0, 1, 1],
            noteSpacing: 5.0...16.0,
            attackTime: 2.5, releaseTime: 9.0,
            brightness: 0.08, reverbWet: 92, masterVolume: 0.09
        ),
        // Fields, villages, natural world
        "earthy": Mood(
            name: "earthy", rootMidi: 55,
            intervals: [0, 2, 4, 7, 9],          // G major pentatonic
            octaves: [0, 0, 1],
            noteSpacing: 3.0...8.0,
            attackTime: 1.0, releaseTime: 4.0,
            brightness: 0.30, reverbWet: 65, masterVolume: 0.13
        ),
        // Retro, nostalgia, gentle floating
        "dreamy": Mood(
            name: "dreamy", rootMidi: 65,
            intervals: [0, 2, 4, 7, 9],          // F major pentatonic
            octaves: [-1, 0, 0, 1],
            noteSpacing: 4.0...11.0,
            attackTime: 1.5, releaseTime: 6.0,
            brightness: 0.18, reverbWet: 80, masterVolume: 0.12
        ),
        // Libraries, scrolls, ancient knowledge
        "mystical": Mood(
            name: "mystical", rootMidi: 59,
            intervals: [0, 3, 5, 7, 10],         // B minor pentatonic
            octaves: [-1, 0, 0, 1],
            noteSpacing: 6.0...15.0,
            attackTime: 2.0, releaseTime: 8.0,
            brightness: 0.10, reverbWet: 90, masterVolume: 0.10
        ),
    ]

    // MARK: - Voice state (lock-free, audio-thread safe)
    //
    // UnsafeMutablePointer<Double> — aligned 8-byte reads/writes are atomic on
    // ARM64. The audio thread reads; the main thread writes. Worst case: a note
    // starts one buffer late. This is the standard CoreAudio pattern.

    private let voiceCount = 8
    private let sampleRate = 44100.0

    private let vFreq: UnsafeMutablePointer<Double>
    private let vPhase: UnsafeMutablePointer<Double>
    private let vAmp: UnsafeMutablePointer<Double>
    private let vTarget: UnsafeMutablePointer<Double>
    private let vAttackDelta: UnsafeMutablePointer<Double>
    private let vReleaseDelta: UnsafeMutablePointer<Double>

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var reverb: AVAudioUnitReverb?
    private var noteTimer: Timer?
    private var currentMood: Mood?

    // MARK: - Lifecycle

    init() {
        let n = voiceCount
        vFreq = .allocate(capacity: n);         vFreq.initialize(repeating: 0, count: n)
        vPhase = .allocate(capacity: n);         vPhase.initialize(repeating: 0, count: n)
        vAmp = .allocate(capacity: n);           vAmp.initialize(repeating: 0, count: n)
        vTarget = .allocate(capacity: n);        vTarget.initialize(repeating: 0, count: n)
        vAttackDelta = .allocate(capacity: n);   vAttackDelta.initialize(repeating: 0, count: n)
        vReleaseDelta = .allocate(capacity: n);  vReleaseDelta.initialize(repeating: 0, count: n)
    }

    deinit {
        stop()
        vFreq.deallocate()
        vPhase.deallocate()
        vAmp.deallocate()
        vTarget.deallocate()
        vAttackDelta.deallocate()
        vReleaseDelta.deallocate()
    }

    // MARK: - Engine control

    func start(mood moodName: String) {
        guard let mood = Self.moods[moodName] else { return }
        if engine != nil { stop() }
        currentMood = mood

        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        // Capture pointers directly — no self capture in render closure
        let freq = vFreq
        let phase = vPhase
        let amp = vAmp
        let target = vTarget
        let aDelta = vAttackDelta
        let rDelta = vReleaseDelta
        let count = voiceCount
        let sr = sampleRate
        let brightness = mood.brightness

        let sourceNode = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bufferList)

            for frame in 0..<Int(frameCount) {
                var sample: Double = 0

                for v in 0..<count {
                    let a = amp[v]
                    let t = target[v]

                    // Skip silent voices
                    guard a > 0.0001 || t > 0 else { continue }

                    // Envelope
                    if t > 0 && a < t {
                        // Attacking — ramp up
                        amp[v] = min(a + aDelta[v], t)
                        if amp[v] >= t {
                            // Attack done — set target to 0 so release begins
                            target[v] = 0
                        }
                    } else if a > 0.0001 {
                        // Releasing — fade down
                        amp[v] = max(a - rDelta[v], 0)
                    } else {
                        amp[v] = 0
                        continue
                    }

                    // Waveform: sine + soft harmonics (warm, round tone)
                    let p = phase[v]
                    var s = sin(p)                                      // fundamental
                    s += sin(p * 2.0) * 0.12 * brightness              // 2nd partial
                    s += sin(p * 3.0) * 0.04 * brightness              // 3rd partial
                    sample += s * amp[v]

                    // Advance phase
                    phase[v] += 2.0 * .pi * freq[v] / sr
                    if phase[v] > .pi * 200 { phase[v] -= .pi * 200 }
                }

                // Soft-clip to prevent any accidental harshness
                let out = Float(tanh(sample * 0.8))

                for ch in 0..<abl.count {
                    abl[ch].mData!.assumingMemoryBound(to: Float.self)[frame] = out
                }
            }
            return noErr
        }

        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.cathedral)
        reverb.wetDryMix = mood.reverbWet

        engine.attach(sourceNode)
        engine.attach(reverb)

        let mixer = engine.mainMixerNode
        mixer.outputVolume = isMuted ? 0 : mood.masterVolume

        engine.connect(sourceNode, to: reverb, format: format)
        engine.connect(reverb, to: mixer, format: format)

        do {
            try engine.start()
        } catch {
            return
        }

        self.engine = engine
        self.sourceNode = sourceNode
        self.reverb = reverb
        isPlaying = true

        // Begin the generative note sequence
        scheduleNote()
    }

    func stop() {
        noteTimer?.invalidate()
        noteTimer = nil
        engine?.stop()
        engine = nil
        sourceNode = nil
        reverb = nil

        for v in 0..<voiceCount {
            vAmp[v] = 0; vTarget[v] = 0; vFreq[v] = 0
            vPhase[v] = 0; vAttackDelta[v] = 0; vReleaseDelta[v] = 0
        }
        currentMood = nil
        isPlaying = false
    }

    /// Crossfade to a new mood. Existing voices release gently; new notes
    /// use the new scale/timing. The reverb and volume shift immediately.
    func changeMood(_ moodName: String) {
        guard let mood = Self.moods[moodName] else { return }
        guard mood != currentMood else { return }

        // If engine isn't running yet, start fresh
        guard engine != nil else {
            start(mood: moodName)
            return
        }

        // Gentle 2-second fadeout of current voices
        for v in 0..<voiceCount {
            if vAmp[v] > 0.001 {
                vTarget[v] = 0
                vReleaseDelta[v] = vAmp[v] / (2.0 * sampleRate)
            }
        }

        currentMood = mood
        reverb?.wetDryMix = mood.reverbWet
        engine?.mainMixerNode.outputVolume = isMuted ? 0 : mood.masterVolume
    }

    // MARK: - Generative note scheduling

    private func scheduleNote() {
        guard let mood = currentMood else { return }
        triggerNote(mood: mood)

        let delay = Double.random(in: mood.noteSpacing)
        noteTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.scheduleNote()
        }
    }

    private func triggerNote(mood: Mood) {
        // Find the quietest voice to reuse
        var best = 0
        var bestAmp = Double.infinity
        for v in 0..<voiceCount {
            if vAmp[v] < bestAmp {
                bestAmp = vAmp[v]
                best = v
            }
        }

        // Pick a random note from the pentatonic scale
        let interval = mood.intervals[Int.random(in: 0..<mood.intervals.count)]
        let octave = mood.octaves[Int.random(in: 0..<mood.octaves.count)]
        let midi = mood.rootMidi + interval + octave * 12
        let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)

        // Gentle amplitude variation
        let noteAmp = 0.06 + Double.random(in: 0...0.05)

        vFreq[best] = frequency
        vPhase[best] = 0
        vTarget[best] = noteAmp
        vAmp[best] = 0.0001          // just above zero to begin attack
        vAttackDelta[best] = noteAmp / (mood.attackTime * sampleRate)
        vReleaseDelta[best] = noteAmp / (mood.releaseTime * sampleRate)
    }
}
