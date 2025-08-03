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
                } else {
                    if spots.isEmpty && shazams.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding()
                    } else {
                        SearchResults
                    }
                }
            }
            .searchable(text: $searchText, isPresented: $searchFocused, prompt: "Shazams, Spots, Places, and More")
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
                        .font(.title2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 2) {
                        Button(action: { if searchHidden { searchFocused = true } }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .tint(searchHidden ? .gray : .clear)
                        }
                        Button(action: { Task { await shazam.startMatching() } }) {
                            Image(systemName: "shazam.logo.fill")
                                .tint(.blue)
                                .fontWeight(.medium)
                                .font(.system(size: 24))
                                .symbolRenderingMode(.multicolor)
                        }
                    }
                }
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
                        .foregroundColor(.gray)
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
    
    private func createShazamStream(_ mediaItem: SHMediaItem) {
        // Create and show ShazamStream
        let stream = ShazamStream(mediaItem: mediaItem, location: location.currentLocation, placemark: location.currentPlacemark, modelContext: modelContext)
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
            toast.show(message: "Shazam error \(extractShazamErrorCode(from: error.localizedDescription))", type: .error, symbol: "shazam.logo.fill")
        default:
            break
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
