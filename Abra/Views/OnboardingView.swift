//
//  OnboardingView.swift
//  Abra
//

import Combine
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var vm: ViewModel
    @StateObject var location = LocationService.shared

    // Control animation properties
    @State private var phase = -1
    @State private var timer: AnyCancellable?
    @State var offset = CGSize(width: 0, height: 16)

    // Permissions state
    @State private var micAuth: Bool = false
    private var locAuth: Bool {
        location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways
    }

    var body: some View {
        Group {
            if locAuth && micAuth {
                arrow
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.easeInOut(duration: 3)),
                            removal: .opacity.animation(.easeInOut(duration: 0.2))
                        )
                    )
            }

            VStack {
                if !locAuth || !micAuth {
                    permissions
                        .transition(
                            .asymmetric(
                                insertion: .opacity.animation(.easeInOut(duration: 3)),
                                removal: .opacity.animation(.easeInOut(duration: 0.3))
                            )
                        )
                } else {
                    control
                        .transition(
                            .asymmetric(
                                insertion: .opacity.animation(.easeInOut(duration: 1)),
                                removal: .opacity.animation(.easeInOut(duration: 0.5))
                            )
                        )
                }
            }
            .padding(32)
            .frame(maxWidth: 500, maxHeight: 300)
        }
    }

    var permissions: some View {
        VStack(alignment: .leading) {
            Text("Before you begin..")
                .font(.system(size: 34, weight: .black))
                .shadow(color: .theme, radius: 12)
            Text("Abra needs a few permissions to be useful.")
                .font(.system(size: 17))
                .padding(.bottom)

            RoundedButton(
                label: locAuth ? "" : "Location",
                systemImage: locAuth ? "checkmark" : "location.fill",
                color: locAuth ? .green : .blue,
                action: { location.requestLocation() }
            )

            RoundedButton(
                label: micAuth ? "" : "Microphone",
                systemImage: micAuth ? "checkmark" : "microphone.fill",
                color: micAuth ? .green : .orange,
                action: {
                    Task { micAuth = await vm.isMicAuthorized }
                }
            )
        }
    }

    var control: some View {
        VStack(alignment: .leading) {
            Text("To finish setup,")
                .font(.system(size: 34, weight: .black))
                .shadow(color: .theme, radius: 12)
            Text("Add Abra’s Control widget for quick access.")
                .padding(.bottom)

            HStack {
                Spacer()

                Image(systemName: "plus")
                    .foregroundColor(phase == 0 ? .primary : .gray)
                    .opacity(phase >= 0 ? 1 : 0)

                Spacer()

                Group {
                    Image(systemName: "plus.circle.fill")
                    Text("Add a Control")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(phase == 1 ? .primary : .gray)
                .opacity(phase >= 1 ? 1 : 0)

                Spacer()

                VStack {
                    Image(systemName: "shazam.logo")
                        .font(.system(size: 34))
                    Text("Recognize\nMusic")
                        .font(.caption2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(phase >= 2 && phase < 5 ? .primary : .gray)
                .opacity(phase >= 2 ? 1 : 0)

                Spacer()
            }
            .onAppear {
                timer = Timer.publish(every: 2, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        withAnimation(.easeInOut(duration: 1)) {
                            phase = (phase + 1)
                        }
                    }
            }
            .onDisappear {
                timer?.cancel()
            }

            Spacer()

            if phase > 5 {
                RoundedButton(
                    label: "I’m ready",
                    systemImage: "checkmark",
                    color: .primary,
                    action: { UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding") }
                )
            }
        }
    }

    var arrow: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 28, weight: .bold))
                    .offset(offset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1)
                            .speed(0.5).repeatCount(3))
                        {
                            offset = CGSize(width: 0, height: 0)
                        }
                    }

                Text("Swipe down for Control Center, then..")
                    .frame(maxWidth: 128)
                    .multilineTextAlignment(.trailing)
                    .font(.caption)
                    .padding(.top, 12)
            }
            .padding(.trailing, 40)
        }
    }
}

#Preview {
    MapView(detent: .constant(.height(65)), sheetSelection: .constant(nil), shazams: [.preview])
        .environmentObject(ViewModel())
        .modelContainer(PreviewSampleData.container)
        .overlay {
            VisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                .edgesIgnoringSafeArea(.all)

            OnboardingView()
                .environmentObject(ViewModel())
        }
}
