//
//  OnboardingView.swift
//  Abra
//

import Combine
import SwiftUI

struct OnboardingView: View {
    @Environment(\.openURL) private var openURL
    @Environment(ShazamProvider.self) private var shazam
    @Environment(LocationProvider.self) private var location

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
                plus
                    .ignoresSafeArea()
                    .opacity(phase >= 0 ? 1 : 0)
                    .foregroundColor(phase < 7 ? .primary : .secondary)

                addAControl
                    .opacity(phase >= 2 ? 1 : 0)
                    .foregroundColor(phase < 7 ? .primary : .secondary)

                arrow
                    .opacity(phase >= 7 ? 1 : 0)
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
            Text("Hi there! 🙂‍↔️")
                .font(.system(size: 34, weight: .black))
                .shadow(color: .theme, radius: 12)
            Text("Abra needs permission to locate Shazams.")
                .padding(.bottom)

            RoundedButton(
                label: locAuth ? "" : "Location",
                systemImage: locAuth ? "checkmark" : "location.fill",
                color: locAuth ? .green : .blue,
                onFirstTap: {
                    location.requestPermission()
                },
                onSubsequentTaps: {
                    if !locAuth {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
            )

            RoundedButton(
                label: micAuth ? "" : "Microphone",
                systemImage: micAuth ? "checkmark" : "microphone.fill",
                color: micAuth ? .green : .orange,
                onFirstTap: {
                    Task {
                        micAuth = await shazam.checkMicrophoneAuthorization()
                    }
                },
                onSubsequentTaps: {
                    if !micAuth {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
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

            VStack(alignment: .leading, spacing: 24) {
                Divider()

                HStack(spacing: 8) {
                    Image("AppIconDisplayable")
                        .resizable()
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 32, height: 32, alignment: .center)

                    Text("Abra")
                        .font(.subheadline.weight(.medium))
                }

                VStack {
                    Image("abra.logo")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(.secondary))
                    Text("Recognize\nMusic")
                        .font(.caption2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .shadow(color: phase == 5 ? .theme : .clear, radius: 12)

                Divider()
            }
            .opacity(phase >= 3 ? 1 : 0)

            Spacer()

            RoundedButton(
                label: "I’m ready",
                systemImage: "checkmark",
                color: .primary,
                action: { UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding") }
            )
            .padding(.top)
            .opacity(phase > 20 ? 1 : 0)
            .disabled(phase <= 20)
        }
        .statusBar(hidden: true)
        .onAppear {
            timer = Timer.publish(every: 0.75, on: .main, in: .common)
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
    }

    var plus: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            Image(systemName: "plus")
                .font(.system(size: 20))
                .padding(.leading, 36)
                .padding(.top, 24)
        }
    }

    var addAControl: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            HStack {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.small)
                Text("Add a Control")
                    .font(.callout.weight(.medium))
            }
            .padding(.bottom, 36)
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
                            .speed(0.5).repeatCount(7))
                        {
                            offset = CGSize(width: 0, height: 0)
                        }
                    }

                Text("Now, swipe down for Control Center")
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
    MapView(modelContext: PreviewSampleData.container.mainContext)
        .environment(SheetProvider())
        .modelContainer(PreviewSampleData.container)
        .overlay {
            VisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                .edgesIgnoringSafeArea(.all)

            OnboardingView()
                .environment(ShazamProvider())
                .environment(LocationProvider())
        }
}
