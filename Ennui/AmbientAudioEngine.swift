import AVFoundation
import Combine

/// Generative ambient audio engine — an Oblique Strategies approach to sound.
///
/// "Ambient Music must be able to accommodate many levels of listening attention
/// without enforcing one in particular; it must be as ignorable as it is
/// interesting." — Brian Eno, liner notes, Music for Airports, 1978.
///
/// Architecture:
/// 1. **Melodic voices** (12) — sine tones with warm harmonics, pentatonic,
///    scheduled at incommensurate intervals so the pattern never repeats.
/// 2. **Drone bed** (2) — sustained root & fifth, very slow amplitude breathing.
///    The harmonic anchor that makes everything else feel like home.
/// 3. **Sub-harmonic** — a barely-audible octave-below shadow of the root drone.
///    Felt more than heard — the warmth in Discreet Music.
/// 4. **Filtered noise bed** — gentle band-passed white noise for spatial air.
///    Like the tape hiss that made analog ambient feel alive.
/// 5. **Tape delay** — AVAudioUnitDelay set long and diffuse, adding temporal
///    smearing so notes blur into each other and decay into the reverb.
/// 6. **Cathedral reverb** — long, deep, the space between the notes.
/// 7. **Slow LFO modulation** — imperceptible pitch drift and amplitude tremolo
///    on every voice. Nothing is static. Everything breathes.
/// 8. **Dyad scheduling** — occasionally two notes arrive together, a fifth
///    or octave apart, creating momentary harmony that dissolves.
/// 9. **Detuning** — each note is offset by ±0.5–2 cents. The beating between
///    near-unison frequencies creates the shimmering warmth of tape machines.
///
/// All state is lock-free via raw pointers. The audio render thread reads;
/// the main thread writes. ARM64 aligned 8-byte access is atomic.
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
        let rootMidi: Int            // MIDI note for the scale root
        let intervals: [Int]         // scale degrees as semitone offsets
        let octaves: [Int]           // relative octave choices
        let noteSpacing: ClosedRange<Double>  // seconds between new notes
        let attackTime: Double       // seconds to fade in
        let releaseTime: Double      // seconds to fade out
        let brightness: Double       // harmonic content 0–1
        let warmth: Double           // sub-harmonic level 0–1
        let noiseLevel: Double       // filtered noise floor 0–1
        let droneMix: Double         // drone volume relative to notes 0–1
        let detuneRange: Double      // max detune in cents
        let reverbWet: Float         // reverb wet/dry 0–100
        let delayWet: Float          // delay wet/dry 0–100
        let delayTime: Double        // delay time in seconds
        let masterVolume: Float      // output volume 0–1

        static func == (lhs: Mood, rhs: Mood) -> Bool { lhs.name == rhs.name }
    }

    /// Six moods covering the emotional range of all scenes.
    /// Pentatonic scales only — no dissonance, ever.
    static let moods: [String: Mood] = [
        // Amber comfort — home, warmth, safety
        "warm": Mood(
            name: "warm", rootMidi: 55,
            intervals: [0, 2, 4, 7, 9],          // G major pentatonic
            octaves: [-2, -1, -1, 0],
            noteSpacing: 3.5...9.0,
            attackTime: 1.4, releaseTime: 6.0,
            brightness: 0.22, warmth: 0.35, noiseLevel: 0.008,
            droneMix: 0.30, detuneRange: 1.5,
            reverbWet: 72, delayWet: 18, delayTime: 2.8,
            masterVolume: 0.16
        ),
        // Rain, ocean, night — cooler, more spacious
        "cool": Mood(
            name: "cool", rootMidi: 55,
            intervals: [0, 3, 5, 7, 10],         // G minor pentatonic
            octaves: [-2, -1, -1, 0],
            noteSpacing: 4.5...13.0,
            attackTime: 2.0, releaseTime: 8.0,
            brightness: 0.12, warmth: 0.25, noiseLevel: 0.012,
            droneMix: 0.25, detuneRange: 1.8,
            reverbWet: 86, delayWet: 25, delayTime: 3.6,
            masterVolume: 0.13
        ),
        // Stars, nebulae, vast emptiness
        "cosmic": Mood(
            name: "cosmic", rootMidi: 50,
            intervals: [0, 2, 4, 7, 9],          // D major pentatonic
            octaves: [-2, -1, -1, 0],
            noteSpacing: 5.0...16.0,
            attackTime: 3.0, releaseTime: 12.0,
            brightness: 0.07, warmth: 0.40, noiseLevel: 0.015,
            droneMix: 0.40, detuneRange: 2.0,
            reverbWet: 92, delayWet: 32, delayTime: 4.2,
            masterVolume: 0.11
        ),
        // Fields, villages, natural world
        "earthy": Mood(
            name: "earthy", rootMidi: 50,
            intervals: [0, 2, 4, 7, 9],          // D major pentatonic
            octaves: [-1, -1, 0, 0],
            noteSpacing: 3.0...8.0,
            attackTime: 1.2, releaseTime: 5.0,
            brightness: 0.25, warmth: 0.20, noiseLevel: 0.006,
            droneMix: 0.20, detuneRange: 1.2,
            reverbWet: 62, delayWet: 14, delayTime: 2.2,
            masterVolume: 0.15
        ),
        // Retro, nostalgia, gentle floating
        "dreamy": Mood(
            name: "dreamy", rootMidi: 53,
            intervals: [0, 2, 4, 7, 9],          // F major pentatonic
            octaves: [-2, -1, -1, 0],
            noteSpacing: 4.0...11.0,
            attackTime: 1.8, releaseTime: 7.0,
            brightness: 0.16, warmth: 0.30, noiseLevel: 0.010,
            droneMix: 0.28, detuneRange: 1.6,
            reverbWet: 78, delayWet: 22, delayTime: 3.2,
            masterVolume: 0.14
        ),
        // Libraries, scrolls, ancient knowledge
        "mystical": Mood(
            name: "mystical", rootMidi: 52,
            intervals: [0, 3, 5, 7, 10],         // E minor pentatonic
            octaves: [-2, -1, -1, 0],
            noteSpacing: 5.0...14.0,
            attackTime: 2.5, releaseTime: 10.0,
            brightness: 0.09, warmth: 0.38, noiseLevel: 0.014,
            droneMix: 0.35, detuneRange: 1.8,
            reverbWet: 90, delayWet: 28, delayTime: 3.8,
            masterVolume: 0.12
        ),
    ]

    // MARK: - Voice layout
    //
    // Voices 0..<12   — melodic (pentatonic notes)
    // Voices 12, 13   — drone root & fifth (sustained, breathing)
    // Voice  14       — sub-harmonic (octave below root drone)

    private let melodicCount = 12
    private let droneStart = 12       // indices 12, 13
    private let subIndex = 14
    private let voiceCount = 15
    private let sampleRate = 44100.0

    private let vFreq: UnsafeMutablePointer<Double>
    private let vPhase: UnsafeMutablePointer<Double>
    private let vAmp: UnsafeMutablePointer<Double>
    private let vTarget: UnsafeMutablePointer<Double>
    private let vAttackDelta: UnsafeMutablePointer<Double>
    private let vReleaseDelta: UnsafeMutablePointer<Double>
    private let vDetune: UnsafeMutablePointer<Double>  // cents offset per voice
    private let vLFOPhase: UnsafeMutablePointer<Double>
    private let vLFORate: UnsafeMutablePointer<Double>  // Hz — very slow

    // Noise state (simple xorshift)
    private let noiseState: UnsafeMutablePointer<UInt64>

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var reverb: AVAudioUnitReverb?
    private var delay: AVAudioUnitDelay?
    private var noteTimer: Timer?
    private var droneTimer: Timer?
    private var currentMood: Mood?

    // MARK: - Lifecycle

    init() {
        let n = voiceCount
        vFreq = .allocate(capacity: n);            vFreq.initialize(repeating: 0, count: n)
        vPhase = .allocate(capacity: n);            vPhase.initialize(repeating: 0, count: n)
        vAmp = .allocate(capacity: n);              vAmp.initialize(repeating: 0, count: n)
        vTarget = .allocate(capacity: n);           vTarget.initialize(repeating: 0, count: n)
        vAttackDelta = .allocate(capacity: n);      vAttackDelta.initialize(repeating: 0, count: n)
        vReleaseDelta = .allocate(capacity: n);     vReleaseDelta.initialize(repeating: 0, count: n)
        vDetune = .allocate(capacity: n);           vDetune.initialize(repeating: 0, count: n)
        vLFOPhase = .allocate(capacity: n);         vLFOPhase.initialize(repeating: 0, count: n)
        vLFORate = .allocate(capacity: n);           vLFORate.initialize(repeating: 0, count: n)
        noiseState = .allocate(capacity: 1);        noiseState.initialize(to: 0x12345678_9abcdef0)
    }

    deinit {
        stop()
        vFreq.deallocate();       vPhase.deallocate()
        vAmp.deallocate();        vTarget.deallocate()
        vAttackDelta.deallocate(); vReleaseDelta.deallocate()
        vDetune.deallocate();     vLFOPhase.deallocate()
        vLFORate.deallocate();    noiseState.deallocate()
    }

    // MARK: - Engine control

    func start(mood moodName: String) {
        guard let mood = Self.moods[moodName] else { return }
        if engine != nil { stop() }
        currentMood = mood

        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        // Assign slow LFO rates to each voice — all different, all very slow
        for v in 0..<voiceCount {
            // 0.03–0.12 Hz — one full cycle every 8–33 seconds
            vLFORate[v] = 0.03 + Double(v) * 0.007
            vLFOPhase[v] = Double(v) * 0.9  // stagger phases
        }

        // Capture pointers directly — no self capture in render closure
        let freq = vFreq, phase = vPhase, amp = vAmp, target = vTarget
        let aDelta = vAttackDelta, rDelta = vReleaseDelta
        let detune = vDetune, lfoPhase = vLFOPhase, lfoRate = vLFORate
        let nState = noiseState
        let count = voiceCount
        let mCount = melodicCount
        let dStart = droneStart
        let subIdx = subIndex
        let sr = sampleRate
        let brightness = mood.brightness
        let warmth = mood.warmth
        let noiseLevel = mood.noiseLevel
        let droneMix = mood.droneMix

        let sourceNode = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bufferList)

            for frame in 0..<Int(frameCount) {
                var sampleL: Double = 0
                var sampleR: Double = 0

                for v in 0..<count {
                    let a = amp[v]
                    let t = target[v]

                    // Skip silent voices
                    guard a > 0.0001 || t > 0 else { continue }

                    // Envelope
                    if t > 0 && a < t {
                        amp[v] = min(a + aDelta[v], t)
                        if amp[v] >= t { target[v] = 0 }
                    } else if a > 0.0001 {
                        amp[v] = max(a - rDelta[v], 0)
                    } else {
                        amp[v] = 0; continue
                    }

                    // LFO — slow amplitude tremolo + slight pitch drift
                    let lp = lfoPhase[v]
                    let lfoAmp = 1.0 + 0.06 * sin(lp)        // ±6% amplitude
                    let lfoPitch = 1.0 + 0.0003 * sin(lp * 1.3) // ±0.05% pitch

                    // Detune: convert cents to frequency multiplier
                    let detuneMul = pow(2.0, detune[v] / 1200.0)

                    // Final frequency with LFO pitch drift + detune
                    let f = freq[v] * detuneMul * lfoPitch

                    let p = phase[v]
                    var s: Double

                    if v == subIdx {
                        // Sub-harmonic: pure sine, very round
                        s = sin(p) * warmth
                    } else if v >= dStart {
                        // Drone voices: sine + very gentle 2nd harmonic
                        s = sin(p) + sin(p * 2.0) * 0.06
                        s *= droneMix
                    } else {
                        // Melodic voices: sine + warm harmonics
                        s = sin(p)                                       // fundamental
                        s += sin(p * 2.0) * 0.15 * brightness           // 2nd partial
                        s += sin(p * 3.0) * 0.06 * brightness           // 3rd partial
                        s += sin(p * 0.5) * 0.04 * warmth               // sub-octave ghost
                    }

                    let voiced = s * amp[v] * lfoAmp

                    // Gentle stereo spread — voices pan slightly based on index
                    let pan = sin(Double(v) * 0.7 + lp * 0.2) * 0.25
                    sampleL += voiced * (0.5 - pan)
                    sampleR += voiced * (0.5 + pan)

                    // Advance phase
                    phase[v] += 2.0 * .pi * f / sr
                    if phase[v] > .pi * 200 { phase[v] -= .pi * 200 }

                    // Advance LFO
                    lfoPhase[v] += 2.0 * .pi * lfoRate[v] / sr
                    if lfoPhase[v] > .pi * 200 { lfoPhase[v] -= .pi * 200 }
                }

                // Filtered noise bed — band-passed white noise for "air"
                // xorshift64 — fast, adequate for audio noise
                var ns = nState[0]
                ns ^= ns << 13; ns ^= ns >> 7; ns ^= ns << 17
                nState[0] = ns
                let rawNoise = Double(Int64(bitPattern: ns)) / Double(Int64.max)
                let noise = rawNoise * noiseLevel
                sampleL += noise * 0.6
                sampleR += noise * 0.4  // slight asymmetry for width

                // Soft-clip via tanh — prevents harshness, adds gentle warmth
                let outL = Float(tanh(sampleL * 0.7))
                let outR = Float(tanh(sampleR * 0.7))

                if abl.count >= 2 {
                    abl[0].mData!.assumingMemoryBound(to: Float.self)[frame] = outL
                    abl[1].mData!.assumingMemoryBound(to: Float.self)[frame] = outR
                } else {
                    // Mono fallback
                    let mono = (outL + outR) * 0.5
                    abl[0].mData!.assumingMemoryBound(to: Float.self)[frame] = mono
                }
            }
            return noErr
        }

        // Reverb — cathedral, the space between notes
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.cathedral)
        reverb.wetDryMix = mood.reverbWet

        // Tape delay — long, diffuse, temporal smearing
        let delay = AVAudioUnitDelay()
        delay.delayTime = mood.delayTime
        delay.feedback = 35            // moderate feedback — echoes that fade
        delay.wetDryMix = mood.delayWet
        delay.lowPassCutoff = 2800      // dark delay, rolls off highs like tape

        engine.attach(sourceNode)
        engine.attach(delay)
        engine.attach(reverb)

        let mixer = engine.mainMixerNode
        mixer.outputVolume = isMuted ? 0 : mood.masterVolume

        // Signal chain: source → delay → reverb → mixer
        engine.connect(sourceNode, to: delay, format: format)
        engine.connect(delay, to: reverb, format: format)
        engine.connect(reverb, to: mixer, format: format)

        do {
            try engine.start()
        } catch {
            return
        }

        self.engine = engine
        self.sourceNode = sourceNode
        self.reverb = reverb
        self.delay = delay
        isPlaying = true

        // Start drones first — they're the foundation
        startDrones(mood: mood)

        // Begin the generative note sequence
        scheduleNote()
    }

    func stop() {
        noteTimer?.invalidate()
        noteTimer = nil
        droneTimer?.invalidate()
        droneTimer = nil
        engine?.stop()
        engine = nil
        sourceNode = nil
        reverb = nil
        delay = nil

        for v in 0..<voiceCount {
            vAmp[v] = 0; vTarget[v] = 0; vFreq[v] = 0
            vPhase[v] = 0; vAttackDelta[v] = 0; vReleaseDelta[v] = 0
            vDetune[v] = 0; vLFOPhase[v] = 0
        }
        currentMood = nil
        isPlaying = false
    }

    /// Crossfade to a new mood. Existing voices release gently; new notes
    /// use the new scale/timing. The reverb, delay, and volume shift immediately.
    func changeMood(_ moodName: String) {
        guard let mood = Self.moods[moodName] else { return }
        guard mood != currentMood else { return }

        // If engine isn't running yet, start fresh
        guard engine != nil else {
            start(mood: moodName)
            return
        }

        // Gentle 3-second fadeout of current melodic voices
        for v in 0..<melodicCount {
            if vAmp[v] > 0.001 {
                vTarget[v] = 0
                vReleaseDelta[v] = vAmp[v] / (3.0 * sampleRate)
            }
        }

        // Drones crossfade over 5 seconds (slower, they're the foundation)
        for v in droneStart...(subIndex) {
            if vAmp[v] > 0.001 {
                vTarget[v] = 0
                vReleaseDelta[v] = vAmp[v] / (5.0 * sampleRate)
            }
        }

        currentMood = mood
        reverb?.wetDryMix = mood.reverbWet
        delay?.delayTime = mood.delayTime
        delay?.wetDryMix = mood.delayWet
        engine?.mainMixerNode.outputVolume = isMuted ? 0 : mood.masterVolume

        // Restart drones in the new key after a brief gap
        droneTimer?.invalidate()
        droneTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self, let mood = self.currentMood else { return }
            self.startDrones(mood: mood)
        }
    }

    // MARK: - Drone voices

    /// Start the root and fifth drones with very slow amplitude breathing.
    /// These are the harmonic bed — nearly subliminal, always present.
    private func startDrones(mood: Mood) {
        let rootFreq = 440.0 * pow(2.0, Double(mood.rootMidi - 69 - 24) / 12.0)  // root, 2 octaves below
        let fifthFreq = rootFreq * 1.5                                             // perfect fifth

        // Root drone
        let rootAmp = 0.035 * mood.droneMix
        vFreq[droneStart] = rootFreq
        vPhase[droneStart] = 0
        vTarget[droneStart] = rootAmp
        vAmp[droneStart] = 0.0001
        vAttackDelta[droneStart] = rootAmp / (6.0 * sampleRate)     // 6 second fade-in
        vReleaseDelta[droneStart] = rootAmp / (10.0 * sampleRate)   // 10 second fade-out
        vDetune[droneStart] = 0.3                                    // very subtle detune

        // Fifth drone
        let fifthAmp = 0.025 * mood.droneMix
        vFreq[droneStart + 1] = fifthFreq
        vPhase[droneStart + 1] = 0
        vTarget[droneStart + 1] = fifthAmp
        vAmp[droneStart + 1] = 0.0001
        vAttackDelta[droneStart + 1] = fifthAmp / (8.0 * sampleRate)
        vReleaseDelta[droneStart + 1] = fifthAmp / (10.0 * sampleRate)
        vDetune[droneStart + 1] = -0.4

        // Sub-harmonic — octave below root, barely audible
        let subAmp = 0.020 * mood.warmth
        vFreq[subIndex] = rootFreq * 0.5
        vPhase[subIndex] = 0
        vTarget[subIndex] = subAmp
        vAmp[subIndex] = 0.0001
        vAttackDelta[subIndex] = subAmp / (10.0 * sampleRate)       // very slow emergence
        vReleaseDelta[subIndex] = subAmp / (12.0 * sampleRate)
        vDetune[subIndex] = 0

        // Drone breathing — periodically re-trigger drones with slight amplitude
        // variation so they never feel static
        droneTimer?.invalidate()
        droneTimer = Timer.scheduledTimer(withTimeInterval: 18.0, repeats: true) { [weak self] _ in
            guard let self, let mood = self.currentMood else { return }
            let breathAmp = 0.035 * mood.droneMix * (0.8 + Double.random(in: 0...0.4))
            self.vTarget[self.droneStart] = breathAmp
            self.vAmp[self.droneStart] = max(self.vAmp[self.droneStart], 0.0001)
            self.vAttackDelta[self.droneStart] = breathAmp / (6.0 * self.sampleRate)

            let breathFifth = 0.025 * mood.droneMix * (0.7 + Double.random(in: 0...0.6))
            self.vTarget[self.droneStart + 1] = breathFifth
            self.vAmp[self.droneStart + 1] = max(self.vAmp[self.droneStart + 1], 0.0001)
            self.vAttackDelta[self.droneStart + 1] = breathFifth / (8.0 * self.sampleRate)
        }
    }

    // MARK: - Generative note scheduling

    private func scheduleNote() {
        guard let mood = currentMood else { return }
        triggerNote(mood: mood)

        // Occasional dyad — schedule a companion note almost simultaneously
        // (a fifth or octave above). ~20% chance. Creates momentary harmony.
        if Double.random(in: 0...1) < 0.20 {
            let companionDelay = Double.random(in: 0.3...1.2)
            Timer.scheduledTimer(withTimeInterval: companionDelay, repeats: false) { [weak self] _ in
                guard let self, let mood = self.currentMood else { return }
                self.triggerCompanionNote(mood: mood)
            }
        }

        let nextDelay = Double.random(in: mood.noteSpacing)
        noteTimer = Timer.scheduledTimer(withTimeInterval: nextDelay, repeats: false) { [weak self] _ in
            self?.scheduleNote()
        }
    }

    private func triggerNote(mood: Mood) {
        // Find the quietest melodic voice to reuse
        var best = 0
        var bestAmp = Double.infinity
        for v in 0..<melodicCount {
            if vAmp[v] < bestAmp {
                bestAmp = vAmp[v]
                best = v
            }
        }

        let interval = mood.intervals[Int.random(in: 0..<mood.intervals.count)]
        let octave = mood.octaves[Int.random(in: 0..<mood.octaves.count)]
        let midi = mood.rootMidi + interval + octave * 12
        let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)

        // Gentle amplitude variation
        let noteAmp = 0.055 + Double.random(in: 0...0.045)

        // Slight random detuning — the shimmer of tape machines
        let cents = Double.random(in: -mood.detuneRange...mood.detuneRange)

        vFreq[best] = frequency
        vPhase[best] = 0
        vTarget[best] = noteAmp
        vAmp[best] = 0.0001
        vAttackDelta[best] = noteAmp / (mood.attackTime * sampleRate)
        vReleaseDelta[best] = noteAmp / (mood.releaseTime * sampleRate)
        vDetune[best] = cents
    }

    /// Trigger a companion note — always consonant (fifth or octave above the
    /// last note's scale degree). Softer than the primary note.
    private func triggerCompanionNote(mood: Mood) {
        var best = 0
        var bestAmp = Double.infinity
        for v in 0..<melodicCount {
            if vAmp[v] < bestAmp {
                bestAmp = vAmp[v]
                best = v
            }
        }

        let interval = mood.intervals[Int.random(in: 0..<mood.intervals.count)]
        let octave = mood.octaves[Int.random(in: 0..<mood.octaves.count)]
        // Companion: a fifth (7 semitones) or octave (12) above
        let companionOffset = Bool.random() ? 7 : 12
        let midi = mood.rootMidi + interval + octave * 12 + companionOffset
        let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)

        // Softer than primary notes
        let noteAmp = 0.035 + Double.random(in: 0...0.025)
        let cents = Double.random(in: -mood.detuneRange...mood.detuneRange)

        // Longer attack for the companion — it blooms in slowly
        let attackMul = 1.5

        vFreq[best] = frequency
        vPhase[best] = 0
        vTarget[best] = noteAmp
        vAmp[best] = 0.0001
        vAttackDelta[best] = noteAmp / (mood.attackTime * attackMul * sampleRate)
        vReleaseDelta[best] = noteAmp / (mood.releaseTime * sampleRate)
        vDetune[best] = cents
    }
}
