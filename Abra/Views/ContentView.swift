//
//  ContentView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("hasCompletedOnboarding") var onboarded: Bool = false
    
    @State var detent: PresentationDetent = .fraction(0.50)
    @State var selection: ShazamStream? = nil
    @State var groupSelection: ShazamStreamGroup? = nil
    @State var searchText: String = ""
    
    @State private var toast = ToastProvider()
    @State private var shazam = ShazamProvider()
    @State private var location = LocationProvider()
    @State private var library = LibraryProvider()
    @State private var music = MusicProvider()
    
    @Query(sort: \ShazamStream.timestamp, order: .reverse)
    var shazams: [ShazamStream]
    
    var filtered: [ShazamStream] {
        guard searchText.isEmpty == false else { return shazams }
        
        return shazams.filter { $0.title.lowercased().contains(searchText.lowercased()) || $0.artist.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        MapView(detent: $detent, sheetSelection: $selection, groupSelection: $groupSelection, shazams: filtered)
            .inspector(isPresented: Binding(
                get: { onboarded },
                set: { _ in }
            )) {
                sheet
                    .sheet(isPresented: Binding(
                        get: { shazam.isMatching },
                        set: { _ in }
                    )) {
                        searching
                    }
                    .sheet(item: $selection) { selection in
                        song(selection)
                    }
                    .sheet(item: $groupSelection) { _ in
                        list
                    }
            }
            .overlay(alignment: .top) {
                // Variable blur at the top of map, makes time/battery legible
                GeometryReader { geom in
                    VariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom)
                        .frame(height: geom.safeAreaInsets.top)
                        .ignoresSafeArea()
                }
            }
            .overlay {
                if !onboarded {
                    VisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    
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
    
    private var sheet: some View {
        SheetView(selection: $selection, searchText: $searchText, filtered: filtered)
            .environment(shazam)
            .environment(location)
            .presentationDetents([.height(65), .fraction(0.50), .fraction(0.999)], selection: $detent)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.50)))
            .interactiveDismissDisabled()
    }
    
    private var searching: some View {
        Searching()
            .presentationDetents([.fraction(0.50)])
            .interactiveDismissDisabled()
            .presentationDragIndicator(.hidden)
            .overlay(
                Button { shazam.stopMatching() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 36))
                        .symbolRenderingMode(.hierarchical)
                        .padding(.vertical)
                        .padding(.trailing, -5)
                },
                alignment: .topTrailing
            )
            .onAppear {
                // We‘ll need this soon
                location.requestLocation()
            }
    }
    
    private var list: some View {
        SongList(
            streams: Binding(
                get: { groupSelection?.wrapped ?? [] },
                set: { update in groupSelection?.wrapped = update }
            ),
            selection: $selection
        )
        .environment(music)
        .presentationDetents([.fraction(0.50), .fraction(0.999)])
        .presentationBackgroundInteraction(.enabled)
    }
    
    private func song(_ stream: ShazamStream) -> some View {
        SongView(stream: stream)
            .environment(library)
            .environment(music)
            .presentationDetents([.fraction(0.50), .fraction(0.999)])
            .presentationBackgroundInteraction(.enabled)
            .edgesIgnoringSafeArea(.bottom)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
