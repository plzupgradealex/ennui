import Foundation

// Simple deterministic RNG for consistent procedural generation
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

// MARK: - Legacy convenience (deprecated — use rng.next() and rng.nextDouble() directly)

@available(*, deprecated, message: "Use rng.next() instead")
func nextUInt64(_ rng: inout SplitMix64) -> UInt64 {
    rng.next()
}

@available(*, deprecated, message: "Use rng.nextDouble() instead")
func nextDouble(_ rng: inout SplitMix64) -> Double {
    rng.nextDouble()
}
