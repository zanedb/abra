//
//  Searching.swift
//  abra
//
//  Created by Zane on 6/26/23.
//

import SwiftUI

struct Searching: View {
    @State private var pulseAmount: CGFloat = 1
    @State private var outerPulseAmount: CGFloat = 1
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.10))
                    .frame(width: 156, height: 156)
                    .scaleEffect(pulseAmount * 1.1)
                Circle()
                    .fill(.blue.opacity(0.20))
                    .frame(width: 104, height: 104)
                    .scaleEffect(pulseAmount * 1.1)
                Circle()
                    .fill(.background)
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseAmount)
                Image(systemName: "shazam.logo.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 72))
                    .scaleEffect(pulseAmount)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.1)
                            .speed(0.1).repeatForever(autoreverses: true)) {
                                pulseAmount = 1.2
                            }
                    }
            }
                .overlay (
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.01))
                            .frame(width: 512, height: 512)
                            .scaleEffect(outerPulseAmount * 1.3)
                        Circle()
                            .fill(.blue.opacity(0.05))
                            .frame(width: 256, height: 256)
                            .scaleEffect(outerPulseAmount)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.1)
                                    .speed(0.1).repeatForever(autoreverses: true)) {
                                        outerPulseAmount = 1.3
                                    }
                            }
//                        Circle()
//                            .stroke(.blue.opacity(0.50), lineWidth: 1)
//                            .frame(width: 512, height: 512)
//                            .scaleEffect(pulseAmount * 0.9)
                    }
                )
            Text("Listening for music")
                .padding(.top, 40)
                .bold()
                .foregroundColor(.primary)
                .font(.system(size: 22))
            Text("Make sure your device can hear the song clearly")
                .padding(.top, 10)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
                .foregroundColor(.gray)
                .font(.system(size: 18))
        }
        .padding(.top, 50)
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    Searching()
}
