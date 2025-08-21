//
//  SongDetail.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SongDetail: View {
    @Environment(\.modelContext) var modelContext
    @Environment(SheetProvider.self) private var view
    
    @Bindable var stream: ShazamStream
    
    @Query var identicalShazamStreams: [ShazamStream]
    
    @Query(sort: \Spot.updatedAt, order: .reverse) private var spots: [Spot]
    
    init(stream: ShazamStream) {
        self.stream = stream
        
        // Find instances of the same Shazam via matching title & artist
        let title = stream.title
        let artist = stream.artist
        let id = stream.persistentModelID
        let predicate = #Predicate<ShazamStream> {
            $0.title == title && $0.artist == artist && $0.persistentModelID != id
        }
        _identicalShazamStreams = Query(filter: predicate, sort: \.timestamp)
    }
    
    private var identicalShazamStream: ShazamStream? {
        identicalShazamStreams.last // Show most recent
    }
    
    @State private var showingSpotSelector = false
    @State private var showingLocationPicker = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Discovered")
                    .font(.subheading)
                
                Spacer()
                
                Menu("Edit") {
                    Button("Location", systemImage: "location.fill", action: editLocation)
                    Button("Spot", systemImage: "mappin.and.ellipse", action: selectSpot)
                }
                .font(.system(size: 13))
            }
            
            Wrapper {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stream.timestamp, style: .time)
                                .font(.system(size: 13, weight: .medium))
                            Text(stream.timestamp, style: .date)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            
                            Text(stream.cityState) // TODO: neighborhood/address info here
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            if let spot = stream.spot {
                                Button(action: {
                                    view.show(spot)
                                }) {
                                    SpotIcon(symbol: spot.symbol, color: Color(spot.color), size: 24, renderingMode: .hierarchical)
                                    
                                    Text(spot.name)
                                        .lineLimit(1)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color(spot.color))
                                }
                            } else {
                                Button("Select", systemImage: "mappin.and.ellipse", action: selectSpot)
                            }
                            
                            if let identical = identicalShazamStream {
                                Spacer()
                                
                                previouslyDiscovered(identical)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .popover(isPresented: $showingSpotSelector) {
            SpotSelector(selection: $stream.spot, newSpotCallback: { createSpot() })
                .presentationDetents([.fraction(0.50), .large])
                .presentationBackground(.thickMaterial)
                .presentationBackgroundInteraction(.enabled)
                .presentationCornerRadius(14)
        }
        .popover(isPresented: $showingLocationPicker) {
            LocationPicker(lat: $stream.latitude, lng: $stream.longitude)
                .presentationDetents([.fraction(0.50), .large])
                .presentationBackground(.thickMaterial)
                .presentationBackgroundInteraction(.enabled)
                .presentationCornerRadius(14)
        }
    }
    
    private func previouslyDiscovered(_ identical: ShazamStream) -> some View {
        Button(action: { view.show(identical) }) {
            Image(systemName: "clock.fill")
            Text("Previously \(identical.attributedPlace)")
                .lineLimit(1)
                .font(.system(size: 13))
                .padding(.leading, -2)
        }
    }
    
    private func selectSpot() {
        showingSpotSelector.toggle()
    }
    
    private func editLocation() {
        showingLocationPicker.toggle()
    }
    
    private func createSpot() {
        showingSpotSelector = false
        // Create new Spot, insert into modelContext, and open for immediate editing
        let spot = Spot(locationFrom: stream, streams: [stream])
        modelContext.insert(spot)
        view.show(spot)
        
        Task {
            spot.appendNearbyShazamStreams(modelContext)
        }
    }
}

#Preview {
    EmptyView()
        .inspector(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
        .modelContainer(PreviewSampleData.container)
}
