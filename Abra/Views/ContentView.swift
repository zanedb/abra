//
//  ContentView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI
import SwiftUIIntrospect

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasCompletedOnboarding") var onboarded: Bool = false

    @State private var sheet = SheetProvider()
    @State private var toast = ToastProvider()
    @State private var shazam = ShazamProvider.shared
    @State private var location = LocationProvider()
    @State private var library = LibraryProvider()
    @State private var motion = MotionProvider()
    @State private var music = MusicProvider()
    @State private var notificationRouteTask: Task<Void, Never>?

    var body: some View {
        Group {
            if !onboarded && !isPreview && !MapBenchmarkConfiguration.isEnabled {
                ZStack {
                    Map(initialPosition: .userLocation(fallback: .automatic))

                    VisualEffectView(
                        effect: UIBlurEffect(style: .systemThinMaterial)
                    )
                    .edgesIgnoringSafeArea(.all)

                    OnboardingView()
                        .environment(shazam)
                        .environment(location)
                        .environment(motion)
                        .environment(music)
                }
            } else {
                MapView()
                    .transition(.blurReplace.animation(.easeInOut(duration: 1.0)))
                    .edgesIgnoringSafeArea(.all)
                    .environment(sheet)
                    .environment(shazam)
                    .environment(location)
                    .environment(motion)
                    .environment(music)
                    .environment(library)
                    .overlay(alignment: .top) {
                        // Variable blur at the top of map, makes time/battery legible
                        GeometryReader { geom in
                            VariableBlurView(
                                maxBlurRadius: 2,
                                direction: .blurredTopClearBottom
                            )
                            .frame(height: geom.safeAreaInsets.top)
                            .ignoresSafeArea()
                        }
                    }
                    .withToastProvider(toast)
            }
        }
        .onAppear {
            shazam.configure(modelContext: modelContext, location: location, motion: motion, sheet: sheet)
            schedulePendingNotificationRoute()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                shazam.retryPendingMatches()
                shazam.resolvePendingMatchLocations()
                schedulePendingNotificationRoute()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: MatchNotificationService.openMatchNotification)) { _ in
            schedulePendingNotificationRoute()
        }
    }

    private func schedulePendingNotificationRoute() {
        notificationRouteTask?.cancel()
        notificationRouteTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await openPendingNotification()
        }
    }

    private func openPendingNotification() async {
        guard scenePhase == .active,
              let id = MatchNotificationService.shared.pendingMatchID else { return }

        let descriptor = FetchDescriptor<ShazamStream>(
            predicate: #Predicate { $0.matchID == id }
        )
        guard let stream = try? modelContext.fetch(descriptor).first else { return }

        let wasSearching = sheet.isSearching
        sheet.dismissSearching()
        if wasSearching {
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard !Task.isCancelled,
              scenePhase == .active,
              MatchNotificationService.shared.pendingMatchID == id else { return }
        sheet.show(stream)
        MatchNotificationService.shared.clearPendingMatchID(if: id)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
