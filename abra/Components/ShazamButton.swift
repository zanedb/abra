//
//  ShazamButton.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import SwiftUI

struct ShazamButton: View {
    
    var searching: Bool
    var start: () -> Void
    var stop: () -> Void
    
    var size: CGFloat?
    var fill: Bool = true
    var color: Bool = true
    
    @State private var pulseAmount: CGFloat = 1
    
    var body: some View {
        Button(action: { searching ? stop() : start() }) {
            Image(systemName: fill ? "shazam.logo.fill" : "shazam.logo")
                .symbolRenderingMode(.multicolor)
                .tint(color ? Color.blue : nil)
                .fontWeight(.medium)
                .font(.system(size: size ?? 156))
                .padding(.vertical)
                .cornerRadius(100)
                .scaleEffect(pulseAmount)
                .onChange(of: searching) { done in
                    if done {
                        startAnimation()
                    } else {
                        stopAnimation()
                    }
                }
        }
    }
    
    func startAnimation() {
        withAnimation(Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.8).repeatForever(autoreverses: true)) {
            pulseAmount = 1.02
        }
    }
    
    func stopAnimation() {
        withAnimation {
            pulseAmount = 1
        }
    }
}

struct ShazamButton_Previews: PreviewProvider {
    static var previews: some View {
        ShazamButton(searching: true, start: { }, stop: { })
    }
}
