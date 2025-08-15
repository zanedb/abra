//
//  Searching.swift
//  Abra
//

import SwiftUI

struct Searching: View {
    @Environment(\.colorScheme) var colorScheme

    var namespace: Namespace.ID

    @State private var motion = MotionProvider()

    @State private var pulseAmount: CGFloat = 1
    @State private var outerPulseAmount: CGFloat = 1
    @State private var ringPulseAmount: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            logoAnimation
                .padding(.bottom)

            Waveform(on: true, size: 4)
                .padding(.vertical)

            Text("Listening for music")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Make sure your device can hear the song clearly")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(8)
        }
        .saturation(motion.isUpsideDown ? 0 : 1)
        .opacity(motion.isUpsideDown ? 0.25 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(gradient: Gradient(
                colors: motion.isUpsideDown
                    ? [.black, .black]
                    : colorScheme == .dark
                    ? [.black.opacity(0.5), .black]
                    : [.blue.opacity(0.75), .blue]),
            startPoint: .top, endPoint: .bottom)
        )
    }

    private var logoAnimation: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 156, height: 156)
                .scaleEffect(pulseAmount * 1.1)
            Circle()
                .fill(.white.opacity(0.20))
                .frame(width: 104, height: 104)
                .scaleEffect(pulseAmount * 1.1)
            Image(systemName: "shazam.logo.fill")
                .foregroundStyle(colorScheme == .dark ? .gray : .blue)
                .font(.system(size: 72))
                .scaleEffect(pulseAmount)
                .symbolRenderingMode(.multicolor)
                .navigationTransition(.zoom(sourceID: "ShazamButton", in: namespace))
        }
        .overlay {
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 256, height: 256)
                .scaleEffect(outerPulseAmount)
            Circle()
                .stroke(.white.opacity(0.50), lineWidth: 1)
                .frame(width: 512, height: 512)
                .scaleEffect(ringPulseAmount * 0.9)
                .opacity(ringPulseAmount == 1 ? 0 : 0.5)
            Circle()
                .stroke(.white.opacity(0.50), lineWidth: 1)
                .frame(width: 768, height: 768)
                .scaleEffect(ringPulseAmount * 0.9)
                .opacity(ringPulseAmount == 1 ? 0 : 0.5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.1)
                .speed(0.1).repeatForever(autoreverses: true))
            {
                pulseAmount = 1.2
            }

            withAnimation(.easeInOut(duration: 0.1)
                .speed(0.1).repeatForever(autoreverses: true))
            {
                outerPulseAmount = 1.3
            }

            withAnimation(.easeInOut(duration: 0.1)
                .speed(0.1).repeatForever(autoreverses: true))
            {
                ringPulseAmount = 1.5
            }
        }
    }
}

#Preview {
    @Previewable @Namespace var animation
    Searching(namespace: animation)
}
