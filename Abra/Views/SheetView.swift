//
//  SheetView.swift
//  Abra
//

import SectionedQuery
import ShazamKit
import SwiftData
import SwiftUI

struct SheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastProvider) private var toast
    @Environment(\.openURL) private var openURL
    @Environment(SheetProvider.self) private var view
    @Environment(ShazamProvider.self) private var shazam
    @Environment(LocationProvider.self) private var location
    @Environment(LibraryProvider.self) private var library
    @Environment(MusicProvider.self) private var music
    
    @SectionedQuery(\.timeGroupedString, sort: [SortDescriptor(\.timestamp, order: .reverse)]) private var timeSectionedStreams: SectionedResults<String, ShazamStream>
    
    @Query(sort: \ShazamStream.timestamp, order: .reverse) private var allShazams: [ShazamStream]
    @Query(sort: \Spot.updatedAt, order: .reverse) private var allSpots: [Spot]
    
    var shazams: [ShazamStream] {
        guard searchText.isEmpty == false else { return allShazams }
        
        return allShazams.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) || $0.cityState.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var spots: [Spot] {
        guard searchText.isEmpty == false else { return allSpots }
        
        return allSpots.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    @Namespace var animation
    
    @State private var searchText: String = ""
    @State private var searchHidden: Bool = false
    @State private var searchFocused: Bool = false
    @State private var hapticTrigger = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if searchText.isEmpty {
                    SpotsList()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .scrollTransition(.animated.threshold(.visible(0.4))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                        }
                        
                    SongsList
                    
                    if spots.isEmpty && shazams.isEmpty {
                        Text("Let‘s Discover")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 72)
                        Text("Tap the Shazam icon to start recognizing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if spots.isEmpty && shazams.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding()
                    } else {
                        SearchResults
                    }
                }
            }
            .background(.thickMaterial)
            .searchable(text: $searchText, isPresented: $searchFocused, placement: .toolbar, prompt: "Shazams, Spots, Places, and More")
            .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
                geometry.contentOffset.y
            }) { oldValue, newValue in
                if oldValue != newValue && newValue > -120 && newValue < 0 {
                    withAnimation { searchHidden = newValue > -57 }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Abra")
                        .font(.title2.weight(.medium))
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 4) {
                        Button(action: { if searchHidden { searchFocused = true } }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .tint(searchHidden ? .gray : .clear)
                        }
                        Button(action: {}) {
                            Image(systemName: "person.crop.circle.fill")
                                .fontWeight(.medium)
                                .font(.button)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { Task { await shazam.startMatching() } }) {
                Image(systemName: "shazam.logo.fill")
                    .imageScale(.large)
                    .font(.largeTitle)
                    .symbolRenderingMode(.multicolor)
                    .shadow(radius: 4, x: 0, y: 4)
                    .matchedTransitionSource(id: "ShazamButton", in: animation)
            }
            .padding()
        }
        .fullScreenCover(isPresented: shazam.isMatchingBinding) {
            searching
        }
        .sheet(isPresented: view.isPresentedBinding) {
            switch view.now {
            case .stream(let stream):
                song(stream)
            case .spot(let item):
                spot(item)
            case .none:
                EmptyView()
            }
        }
        .onChange(of: shazam.status) {
            if case .matched(let song) = shazam.status {
                createShazamStream(song)
            }
            
            if case .error(let error) = shazam.status {
                handleShazamAPIError(error)
            }
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }
    
    private var SongsList: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(timeSectionedStreams) { section in
                Section {
                    ForEach(section) { shazam in
                        Button(action: { view.show(shazam) }) {
                            SongRow(stream: shazam)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, shazam == section.last ? 12 : 0)
                        
                        if shazam != section.last {
                            Divider()
                                .padding(.leading, 125)
                        }
                    }
                } header: {
                    Text("\(section.id)")
                        .foregroundStyle(.gray)
                        .font(.subheading)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThickMaterial)
                }
            }
        }
    }
    
    private var SearchResults: some View {
        LazyVStack(alignment: .leading) {
            Section {
                ForEach(spots, id: \.id) { spot in
                    Button(action: { view.show(spot) }) {
                        SpotRow(spot: spot)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 60)
                }
            }
            
            Section {
                ForEach(shazams, id: \.id) { stream in
                    Button(action: { view.show(stream) }) {
                        SongRowMini(stream: stream)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var searching: some View {
        Searching(namespace: animation)
            .overlay(alignment: .topTrailing) {
                DismissButton(foreground: .white, font: .buttonLarge, action: { shazam.stopMatching() })
                    .padding(.horizontal)
            }
            .onAppear {
                // If location was "allow once" request again
                if location.authorizationStatus == .notDetermined {
                    location.requestPermission()
                }
                // We‘ll need this soon
                location.requestLocation()
            }
    }
    
    private func song(_ stream: ShazamStream) -> some View {
        SongView(stream: stream)
            .presentationDetents([.fraction(0.50), .large])
            .presentationInspector()
            .edgesIgnoringSafeArea(.bottom)
            .prefersEdgeAttachedInCompactHeight()
    }
    
    private func spot(_ spot: Spot) -> some View {
        SpotView(spot: spot)
            .presentationDetents([.fraction(0.50), .large])
            .presentationInspector()
            .prefersEdgeAttachedInCompactHeight()
    }
    
    private func createShazamStream(_ mediaItem: SHMediaItem) {
        // Create and show ShazamStream
        let stream = ShazamStream(mediaItem: mediaItem, location: location.currentLocation, placemark: location.currentPlacemark)
        modelContext.insert(stream)
        try? modelContext.save()
        view.show(stream)
        hapticTrigger.toggle()
        
        // If Spot exists with similar latitude/longitude, set it automatically
        Task {
            stream.spotIt(context: modelContext)
        }
    }
    
    private func handleShazamAPIError(_ error: ShazamError) {
        switch error {
        case .noMatch:
            toast.show(message: "No match found", type: .info, symbol: "shazam.logo.fill")
        case .matchFailed(let error):
            guard let errorCode = extractShazamErrorCode(from: error), errorCode != "(null)" else { return }
            toast.show(message: errorCode, type: .error, symbol: "shazam.logo.fill")
        default:
            break
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
