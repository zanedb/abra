//
//  Waveform.swift
//  Abra
//

import SwiftUI

struct Waveform: View {
    var on: Bool
    var size: CGFloat = 2
    
    var body: some View {
        HStack(spacing: size) {
            ForEach(0 ..< 5) { index in
                AnimatedBar(
                    isAnimating: on,
                    delay: Double(index) * 0.1,
                    initial: size
                )
            }
        }
    }
}

struct AnimatedBar: View {
    let isAnimating: Bool
    let delay: Double
    let initial: CGFloat
    
    @State private var height: CGFloat
    
    init(isAnimating: Bool, delay: Double, initial: CGFloat) {
        self.isAnimating = isAnimating
        self.delay = delay
        self.initial = initial
        _height = .init(initialValue: initial)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: initial / 2)
            .fill(.white)
            .frame(width: initial, height: height)
            .animation(
                isAnimating ?
                    Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay) :
                    Animation.easeInOut(duration: 0.3),
                value: height
            )
            .onAppear {
                updateHeight()
            }
            .onChange(of: isAnimating) {
                updateHeight()
            }
    }
    
    private func updateHeight() {
        if isAnimating {
            // Random heights for the bars when animating
            let heights: [CGFloat] = [initial * 4, initial * 6, initial * 8, initial * 5, initial * 3]
            height = heights[Int(delay * 10) % heights.count]
        } else {
            // Collapsed state
            height = initial
        }
    }
}
