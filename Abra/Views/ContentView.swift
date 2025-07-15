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
    
    @State var searchText: String = ""
    @State var detent: PresentationDetent = .fraction(0.50)
    
    @State private var sheet = SheetProvider()
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
        MapView(detent: $detent, shazams: filtered)
            .environment(sheet)
            .sheet(isPresented: Binding(
                get: { onboarded || isPreview },
                set: { _ in }
            )) {
                inspector
                    .popover(isPresented: Binding(
                        get: { shazam.isMatching },
                        set: { _ in }
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
    
    private var inspector: some View {
        SheetView(searchText: $searchText, filtered: filtered)
            .environment(sheet)
            .environment(shazam)
            .environment(location)
            .environment(music)
            .presentationDetents([.height(65), .fraction(0.50), .fraction(0.999)], selection: $detent)
            .presentationInspector()
            .interactiveDismissDisabled()
            .introspect(.sheet, on: .iOS(.v18)) { sheetView in
                sheetView.prefersEdgeAttachedInCompactHeight = true // Disable full-width in landscape
                sheetView.widthFollowsPreferredContentSizeWhenEdgeAttached = true // Use landscape width
                sheetView.prefersScrollingExpandsWhenScrolledToEdge = false // Allow scrolling in .medium
                sheetView.setValue(1, forKey: "horizontalAlignment") // Leading-aligned sheet in landscape/iPad (width-dependent)
                sheetView.setValue(true, forKey: "wantsBottomAttached")
                sheetView.setValue(10, forKey: "marginInRegularWidthRegularHeight")
            }
    }
    
    private var searching: some View {
        Searching()
            .presentationDetents([.fraction(0.50)])
            .interactiveDismissDisabled()
            .presentationDragIndicator(.hidden)
            .presentationBackground(.thickMaterial)
            .presentationCornerRadius(18)
            .overlay(
                Button { shazam.stopMatching() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 36))
                        .symbolRenderingMode(.hierarchical)
                        .padding(.vertical)
                        .padding(.trailing, -10)
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
            .environment(sheet)
            .environment(library)
            .environment(music)
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
