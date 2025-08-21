//
//  ContentView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI
import SwiftUIIntrospect

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("hasCompletedOnboarding") var onboarded: Bool = false
    
    @State private var sheet = SheetProvider()
    @State private var toast = ToastProvider()
    @State private var shazam = ShazamProvider()
    @State private var location = LocationProvider()
    @State private var library = LibraryProvider()
    @State private var music = MusicProvider()
    
    var body: some View {
        if !onboarded && !isPreview {
            ZStack {
                Map(initialPosition: .userLocation(fallback: .automatic))
                
                VisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                    .edgesIgnoringSafeArea(.all)
                        
                OnboardingView()
                    .environment(shazam)
                    .environment(location)
                    .environment(music)
            }
        } else {
            MapView()
                .transition(.blurReplace.animation(.easeInOut(duration: 1.0)))
                .edgesIgnoringSafeArea(.all)
                .environment(sheet)
                .environment(shazam)
                .environment(location)
                .environment(music)
                .environment(library)
                .overlay(alignment: .top) {
                    // Variable blur at the top of map, makes time/battery legible
                    GeometryReader { geom in
                        VariableBlurView(maxBlurRadius: 2, direction: .blurredTopClearBottom)
                            .frame(height: geom.safeAreaInsets.top)
                            .ignoresSafeArea()
                    }
                }
                .onChange(of: scenePhase) {
                    // If app is minimized and no session is active, stop recording
                    // Note: scenePhase is pretty inconsistent & should probably be handled with a better mechanism in the future
                    if scenePhase == .inactive && shazam.status != .matching {
                        print("Scene phase changed to inactive, stopping matching")
                        shazam.stopMatching()
                    }
                }
                .withToastProvider(toast)
                .withToastOverlay(using: toast)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
