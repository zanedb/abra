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
    @Environment(MusicProvider.self) private var music

    // Control animation properties
    @State private var phase = 0
    @State private var timer: AnyCancellable?
    @State var offset = CGSize(width: 0, height: 16)

    // Permissions
    @State private var micAuth: Bool = false
    private var locAuth: Bool {
        location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways
    }

    private var musicAuth: Bool {
        music.authorizationStatus == .authorized
    }

    enum OnboardingState {
        case permissions
        case control
    }

    private var step: OnboardingState {
        if !locAuth || !micAuth || !musicAuth {
            return .permissions
        } else {
            return .control
        }
    }

    var body: some View {
        Group {
            if step == .control {
                plus
                    .ignoresSafeArea()

                addAControl

                arrow
            }

            VStack {
                switch step {
                case .permissions:
                    permissions
                        .transition(
                            .asymmetric(
                                insertion: .opacity.animation(.easeInOut(duration: 3)),
                                removal: .opacity.animation(.easeInOut(duration: 0.25))
                            )
                        )
                case .control:
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
            .frame(maxWidth: 500, maxHeight: 375)
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading) {
            Text("Abra puts your Shazams on a map.")
                .font(.system(size: 34, weight: .black))
                .padding(.bottom, 4)
                .shadow(color: .theme, radius: 12)
            Text("Grant permissions to get started.")
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

            RoundedButton(
                label: musicAuth ? "" : "Song Lookup",
                systemImage: musicAuth ? "checkmark" : "music.note",
                color: musicAuth ? .green : .red,
                onFirstTap: {
                    Task {
                        await music.authorize()
                    }
                },
                onSubsequentTaps: {
                    if !musicAuth {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
            )
        }
    }

    private var control: some View {
        VStack(alignment: .leading) {
            Text("To finish setup,")
                .font(.system(size: 34, weight: .black))
                .shadow(color: .theme, radius: 12)
            Text("Add Abra’s Control widget for quick access.")
                .padding(.bottom)

            controlButton

            RoundedButton(
                label: "I’m ready",
                systemImage: "checkmark",
                color: .primary,
                action: { UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding") }
            )
            .padding(.top)
            .opacity(phase > 32 ? 1 : 0)
            .disabled(phase <= 32)
        }
        .statusBar(hidden: true)
        .onAppear {
            timer = Timer.publish(every: 0.5, on: .main, in: .common)
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

    private var plus: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            HStack(alignment: .center) {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundStyle(3 ... 4 ~= phase ? .primary : .secondary)

                Guide("1")
                    .padding(.leading, 4)
                    .scaleEffect(phase > 2 ? 1 : 0)
            }
            .padding(.leading, 36)
            .padding(.top, 12)
        }
    }

    var addAControl: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            HStack {
                Group {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.small)
                    Text("Add a Control")
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(5 ... 6 ~= phase ? .primary : .secondary)

                Guide("2")
                    .padding(.leading, 4)
                    .scaleEffect(phase > 4 ? 1 : 0)
            }
            .padding(.bottom, 36)
        }
    }

    private var controlButton: some View {
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

            VStack(alignment: .leading) {
                HStack {
                    Image("abra.logo")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(.secondary))
                        .shadow(color: phase == 8 ? .theme : .clear, radius: 12)
                    Guide("3")
                        .padding(.leading, 12)
                        .scaleEffect(phase > 6 ? 1 : 0)
                }
                Text("Recognize\nMusic")
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Divider()
        }
    }

    private var arrow: some View {
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
        .opacity(phase >= 12 ? 1 : 0)
    }

    private func Guide(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.white)
            .font(.headline.weight(.bold))
            .padding(12)
            .background(.blue)
            .clipShape(Circle())
    }
}

#Preview {
    MapView(modelContext: PreviewSampleData.container.mainContext, detent: .fraction(0.50))
        .edgesIgnoringSafeArea(.all)
        .environment(SheetProvider())
        .modelContainer(PreviewSampleData.container)
        .overlay {
            VisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                .edgesIgnoringSafeArea(.all)

            OnboardingView()
                .environment(ShazamProvider())
                .environment(LocationProvider())
                .environment(MusicProvider())
        }
}
