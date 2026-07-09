//
//  Searching.swift
//  Abra
//

import SwiftUI

struct Searching: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(MotionProvider.self) var motion
    @Environment(ShazamProvider.self) var shazam

    var namespace: Namespace.ID

    @State private var basePulse: CGFloat = 1
    @State private var recordingBright: Bool = true

    private var continuous: Bool { shazam.continuous }

    var body: some View {
        NavigationStack {
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

                ContinuousButton
                    .padding(.top)
            }
            .saturation(motion.isUpsideDown ? 0 : 1)
            .opacity(motion.isUpsideDown ? 0.25 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(gradient: Gradient(
                    colors: motion.isUpsideDown
                    ? [.black, .black]
                    : continuous
                    ? [.black, .black]
                    : colorScheme == .dark
                    ? [.black.opacity(0.5), .black]
                    : [.blue.opacity(0.75), .blue]),
                               startPoint: .top, endPoint: .bottom)
                .animation(.easeInOut(duration: 0.5), value: continuous)
                .ignoresSafeArea()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DismissButton(foreground: .white)
                }
            }
        }
        .navigationTransition(.zoom(sourceID: "ShazamButton", in: namespace))
    }

    private var logoAnimation: some View {
        ZStack {
            // Outer background circle
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 156, height: 156)
                .scaleEffect(scaleForRadius(156))

            // Middle circle
            Circle()
                .fill(.white.opacity(0.20))
                .frame(width: 104, height: 104)
                .scaleEffect(scaleForRadius(104))

            // Logo
            Image(systemName: "shazam.logo.fill")
                .foregroundStyle(colorScheme == .dark ? .gray : .blue)
                .font(.system(size: 72))
                .scaleEffect(scaleForRadius(72))
                .symbolRenderingMode(.multicolor)
        }
        .overlay {
            // Large outer circle
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 256, height: 256)
                .scaleEffect(scaleForRadius(256))

            // Expanding rings
            Circle()
                .stroke(.white.opacity(0.50), lineWidth: 1)
                .frame(width: 512, height: 512)
                .scaleEffect(scaleForRadius(512))
                .opacity(basePulse == 1 ? 0 : 0.5)

            Circle()
                .stroke(.white.opacity(0.50), lineWidth: 1)
                .frame(width: 768, height: 768)
                .scaleEffect(scaleForRadius(768))
                .opacity(basePulse == 1 ? 0 : 0.5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.1)
                .speed(0.1).repeatForever(autoreverses: true))
            {
                basePulse = 1.15
            }
        }
    }

    // Calculate scale based on radius
    private func scaleForRadius(_ radius: CGFloat) -> CGFloat {
        let baseRadius: CGFloat = 72 // Logo
        let pulseDelta = basePulse - 1.0
        let radiusRatio = radius / baseRadius
        let scaledDelta = pulseDelta * radiusRatio
        return 1.0 + scaledDelta
    }

    private var ContinuousButton: some View {
        Button {
            shazam.continuous.toggle()
            if shazam.continuous {
                recordingBright = true
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    recordingBright = false
                }
            }
        } label: {
            HStack(spacing: 8) {
                if continuous {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                        .opacity(recordingBright ? 1 : 0.15)
                        .animation(
                            .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                            value: recordingBright
                        )
                        .transition(.scale(scale: 0, anchor: .trailing).combined(with: .opacity))
                }
                Text("Continuous")
                    .font(.subheadline.weight(.medium))
            }
            .animation(.spring(duration: 0.3), value: continuous)
            .foregroundStyle(continuous ? .white : .white.opacity(0.4))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white.opacity(continuous ? 0.15 : 0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @Namespace var animation
    Searching(namespace: animation)
        .environment(MotionProvider())
        .environment(ShazamProvider())
}
