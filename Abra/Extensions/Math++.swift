//
//  Math++.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 12/20/25.
//

/// Clamped
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

/// Linear interpolation between `a` and `b` by `t` in [0, 1]
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

// Remap smoothed expansion t ∈ [0,1] so it stays 0 until 0.5,
// then linearly ramps to 1 over [0.5, 1.0]
func remapHalfRange(_ t: Double) -> Double {
    max(0.0, (t - 0.5) / 0.5)
}

/// A smoothed version of expansion for softer transitions. Adjust `k` to taste.
/// k = 1.0 is linear; higher k makes ease-in-out more pronounced.
func smooth(_ t: Double, k: Double = 1.0) -> Double {
    let x = t.clamped(to: 0...1)
    // Smoothstep-like curve, scaled by k
    let s = x * x * (3 - 2 * x)  // classic smoothstep
    return lerp(x, s, (k - 1).clamped(to: 0...1))
}
