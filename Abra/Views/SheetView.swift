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
    
    @Binding var height: CGFloat
    
    @State private var lastHeight: CGFloat = 0
    @State private var debounceWorkItem: DispatchWorkItem?
    
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
                        .font(.title2.weight(.medium))
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
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { proxy in
            let newHeight = proxy.height
            
            // Only update if height changes meaningfully (e.g., > 2pt)
            guard abs(newHeight - lastHeight) > 2 else { return }
            lastHeight = newHeight
            
            guard newHeight < 400 else { return } // Hardcoded value of .fraction(0.50) sheet, on my iPhone.. yes it's not ideal

            // Cancel any pending debounce
            debounceWorkItem?.cancel()

            // Debounce update to avoid rapid firing
            let workItem = DispatchWorkItem {
                height = newHeight
                print("Sheet height updated:", newHeight)
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
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
