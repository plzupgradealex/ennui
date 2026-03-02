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

func nextUInt64(_ rng: inout SplitMix64) -> UInt64 {
    rng.state &+= 0x9e3779b97f4a7c15
    var z = rng.state
    z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
    z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
    return z ^ (z >> 31)
}

func nextDouble(_ rng: inout SplitMix64) -> Double {
    Double(nextUInt64(&rng) >> 11) / Double(1 << 53)
}
