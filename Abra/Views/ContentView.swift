//
//  ContentView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("hasCompletedOnboarding") var onboarded: Bool = true // MARK: FOR PREVIEW
    
    @State var detent: PresentationDetent = .fraction(0.50)
    @State var selection: ShazamStream? = nil
    @State var groupSelection: ShazamStreamGroup? = nil
    @State var searchText: String = ""
    
    @State private var toast = ToastProvider()
    @State private var shazam = ShazamProvider()
    @State private var location = LocationProvider()
    @State private var library = LibraryProvider()
    
    @Query(sort: \ShazamStream.timestamp, order: .reverse)
    var shazams: [ShazamStream]
    
    var filtered: [ShazamStream] {
        guard searchText.isEmpty == false else { return shazams }
        
        return shazams.filter { $0.title.lowercased().contains(searchText.lowercased()) }
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
                    .sheet(item: $groupSelection) { group in
                        list(group)
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
                if scenePhase == .inactive && shazam.status != .matching {
                    shazam.stopMatching()
                }
                
                // Now do the opposite
                if scenePhase == .active && shazam.status == .idle {
                    shazam.prepare()
                }
            }
            .withToastProvider(toast)
            .withToastOverlay(using: toast)
    }
    
    private var sheet: some View {
        SheetView(detent: $detent, selection: $selection, searchText: $searchText, filtered: filtered)
            .environment(shazam)
            .environment(location)
            .presentationDetents([.height(65), .fraction(0.50), .large], selection: $detent)
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
    
    private func song(_ stream: ShazamStream) -> some View {
        SongView(stream: stream)
            .environment(library)
            .presentationDetents([.fraction(0.50), .large])
            .presentationBackgroundInteraction(.enabled)
            .edgesIgnoringSafeArea(.bottom)
    }
    
    private func list(_ group: ShazamStreamGroup) -> some View {
        SongList(streams: group.wrapped, selection: $selection)
            .presentationDetents([.fraction(0.50), .large])
            .presentationBackgroundInteraction(.enabled)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
