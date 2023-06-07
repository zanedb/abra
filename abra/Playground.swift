//
//  Playground.swift
//  abra
//
//  Created by Zane on 6/6/23.
//

import SwiftUI

struct Playground: View {
    @Binding var listening: Bool
    @Binding var listShown: Bool
    @State private var pulseAmount: CGFloat = 1
    
    var body: some View {
        NavigationStack {
            VStack {
                Button(action: { listening = !listening }) {
                    Image(systemName: "shazam.logo.fill")
                        .tint(Color.blue)
                        .fontWeight(.medium)
                        .font(.system(size: 156))
                        .padding(.vertical)
                        .cornerRadius(100)
                        .scaleEffect(pulseAmount)
                        .onAppear(perform: startAnimation)
                        .onChange(of: listening) { done in
                            if done {
                                stopAnimation()
                            } else {
                                startAnimation()
                            }
                        }
                }
                Text(listening ? "Listening…" : "Tap to Shazam")
                    .fontWeight(.medium)
                    .foregroundColor(Color.gray)
                    .font(.system(size: 18))
                    .padding(.bottom)
            }
            if (listShown) {
                List {
                    Text("Lemon")
                }
            }
        }
    }
}

// todo make a button component and move this logic there
private extension Playground {
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

struct Playground_Previews: PreviewProvider {
    static var previews: some View {
        Playground(listening: .constant(true), listShown: .constant(true))
    }
}
