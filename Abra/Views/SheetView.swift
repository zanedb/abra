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
    @Environment(ShazamProvider.self) private var shazam
    @Environment(LocationProvider.self) private var location
    
    @Binding var selection: ShazamStream?
    @Binding var searchText: String
    
    var filtered: [ShazamStream]
    
    @SectionedQuery(\.timeGroupedString, sort: [SortDescriptor(\.timestamp, order: .reverse)]) private var timeSections: SectionedResults<String, ShazamStream>
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                SearchBar(text: $searchText, placeholder: "Search Shazams")
                    
                Button(action: { Task { await shazam.startMatching() } }) {
                    Image(systemName: "shazam.logo.fill")
                        .symbolRenderingMode(.multicolor)
                        .tint(.blue)
                        .fontWeight(.medium)
                        .font(.system(size: 36))
                }
                .padding(.leading, -3)
                .padding(.trailing, 12)
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)
            
            if searchText.isEmpty && filtered.isEmpty {
                ContentUnavailableView {} description: { Text("Your library is empty.") }
            } else if searchText.isEmpty {
                List {
                    ForEach(timeSections) { section in
                        Section(header: Text("\(section.id)")) {
                            ForEach(section, id: \.self) { shazam in
                                Button(action: { selection = shazam }) {
                                    SongRow(stream: shazam)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listSectionSeparator(.hidden, edges: .bottom)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            } else if !searchText.isEmpty && filtered.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "moon.stars")
                } description: {
                    Text("Try a new search.")
                }
            } else {
                List {
                    ForEach(filtered, id: \.id) { shazam in
                        Button(action: { selection = shazam }) {
                            SongRow(stream: shazam)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
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
    }
    
    private func createShazamStream(_ mediaItem: SHMediaItem) {
        // Handle lack of available location
        guard location.currentLocation != nil else {
            toast.show(
                message: "Location unavailable",
                type: .error,
                symbol: "location.slash.fill",
                action: {
                    // On permissions issue, tapping takes you right to app settings!
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            )
            return
        }
        
        // Create object
        let stream = ShazamStream(
            title: mediaItem.title ?? "Unknown Title",
            artist: mediaItem.artist ?? "Unknown Artist",
            isExplicit: mediaItem.explicitContent,
            artworkURL: mediaItem.artworkURL ?? URL(string: "https://zane.link/abra-unavailable")!,
            latitude: location.currentLocation!.coordinate.latitude,
            longitude: location.currentLocation!.coordinate.longitude
        )
        
        // Fill optional properties
        stream.isrc = mediaItem.isrc
        stream.shazamID = mediaItem.shazamID
        stream.shazamLibraryID = mediaItem.id
        stream.appleMusicID = mediaItem.appleMusicID
        stream.appleMusicURL = mediaItem.appleMusicURL
        stream.altitude = location.currentLocation?.altitude
        stream.speed = location.currentLocation?.speed
        stream.thoroughfare = location.currentPlacemark?.thoroughfare
        stream.city = location.currentPlacemark?.locality
        stream.state = location.currentPlacemark?.administrativeArea
        stream.country = location.currentPlacemark?.country
        stream.countryCode = location.currentPlacemark?.isoCountryCode
        
        // Save in ModelContext
        modelContext.insert(stream)
        try? modelContext.save()
        
        // Set selection to newly created item
        selection = stream
    }
    
    private func handleShazamAPIError(_ error: ShazamError) {
        switch error {
        case .noMatch:
            toast.show(message: "No match found", type: .info, symbol: "shazam.logo.fill")
        case .matchFailed(let error):
            toast.show(message: "Shazam error \(extractShazamErrorCode(from: error.localizedDescription))", type: .error, symbol: "shazam.logo.fill")
            Task { await shazam.startMatching() } // retry
        default:
            break
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
