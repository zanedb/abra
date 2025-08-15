//
//  ContentView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI
import SwiftUIIntrospect

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("hasCompletedOnboarding") var onboarded: Bool = false
    @Namespace var animation
    
    @State var detent: PresentationDetent = .fraction(0.50)
    
    @State private var sheet = SheetProvider()
    @State private var toast = ToastProvider()
    @State private var shazam = ShazamProvider()
    @State private var location = LocationProvider()
    @State private var library = LibraryProvider()
    @State private var music = MusicProvider()
    
    var body: some View {
        MapView(modelContext: context)
            .edgesIgnoringSafeArea(.all)
            .environment(sheet)
            .sheet(isPresented: Binding(
                get: { onboarded || isPreview },
                set: { _ in }
            )) {
                inspector
                    .fullScreenCover(isPresented: Binding(
                        get: { shazam.isMatching },
                        set: { _ in shazam.stopMatching() }
                    )) {
                        searching
                    }
                    .sheet(isPresented: Binding<Bool>(
                        get: { sheet.now != .none },
                        set: { _ in sheet.now = .none }
                    )) {
                        switch sheet.now {
                        case .stream(let stream):
                            song(stream)
                        case .spot(let item):
                            spot(item)
                        case .none:
                            EmptyView()
                        }
                    }
            }
            .overlay(alignment: .top) {
                // Variable blur at the top of map, makes time/battery legible
                GeometryReader { geom in
                    VariableBlurView(maxBlurRadius: 2, direction: .blurredTopClearBottom)
                        .frame(height: geom.safeAreaInsets.top)
                        .ignoresSafeArea()
                }
            }
            .overlay {
                if !onboarded && !isPreview {
                    VisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        
                    OnboardingView()
                        .environment(shazam)
                        .environment(location)
                        .transition(.blurReplace.animation(.easeInOut(duration: 0.25)))
                }
            }
            .onChange(of: scenePhase) {
                // If app is minimized and no session is active, stop recording
                // Note: scenePhase is pretty inconsistent & should probably be handled with a better mechanism in the future
                if scenePhase == .inactive && shazam.status != .matching && onboarded {
                    print("Scene phase changed to inactive, stopping matching")
                    shazam.stopMatching()
                }
            }
            .withToastProvider(toast)
            .withToastOverlay(using: toast)
    }
    
    private var inspector: some View {
        SheetView()
            .environment(sheet)
            .environment(shazam)
            .environment(location)
            .environment(music)
            .presentationDetents([.height(96), .fraction(0.50), .fraction(0.999)], selection: $detent)
            .presentationInspector()
            .interactiveDismissDisabled()
            .prefersEdgeAttachedInCompactHeight(allowScrollingInMediumDetent: true)
    }
    
    private var searching: some View {
        Searching(namespace: animation)
            .overlay(alignment: .topTrailing) {
                Button { shazam.stopMatching() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal)
            }
            .onAppear {
                // If location was "allow once" request again
                if location.authorizationStatus == .notDetermined && onboarded {
                    location.requestPermission()
                }
                // We‘ll need this soon
                location.requestLocation()
            }
    }
    
    private func song(_ stream: ShazamStream) -> some View {
        SongView(stream: stream)
            .environment(sheet)
            .environment(shazam)
            .environment(library)
            .environment(music)
            .environment(location)
            .presentationDetents([.height(65), .fraction(0.50), .fraction(0.999)], selection: $sheet.detent)
            .presentationInspector()
            .edgesIgnoringSafeArea(.bottom)
            .interactiveDismissDisabled()
            .prefersEdgeAttachedInCompactHeight()
    }
    
    private func spot(_ spot: Spot) -> some View {
        SpotView(spot: spot)
            .environment(sheet)
            .environment(music)
            .presentationDetents([.height(65), .fraction(0.50), .fraction(0.999)], selection: $sheet.detent)
            .presentationInspector()
            .interactiveDismissDisabled()
            .prefersEdgeAttachedInCompactHeight()
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
