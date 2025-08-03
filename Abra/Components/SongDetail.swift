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
    @Query var spotEvents: [Event]
    
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
        
        // Find potential events if a spot has been selected
        let spotId = stream.spot?.persistentModelID
        let eventPredicate = #Predicate<Event> {
            $0.spot?.persistentModelID == spotId
        }
        _spotEvents = Query(filter: eventPredicate, sort: \.updatedAt)
    }
    
    private var type: SpotType {
        stream.modality == .driving ? .vehicle : .place
    }
    
    private var identicalShazamStream: ShazamStream? {
        identicalShazamStreams.last // Show most recent
    }
    
    @State private var showingSpotSelector = false
    @State private var showingLocationPicker = false
    @State private var eventAlertShown = false
    @State private var eventName = ""
    
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
        
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.background)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 14
                    ))
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stream.timestamp, style: .time)
                                .font(.system(size: 13, weight: .medium))
                            Text(stream.timestamp, style: .date)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Text(stream.cityState) // TODO: neighborhood/address info here
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
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
                            
                            if !identicalShazamStreams.isEmpty {
                                Spacer()
                                
                                previouslyDiscovered
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .popover(isPresented: $showingSpotSelector) {
            SpotSelector(selection: $stream.spot, newSpotCallback: { createSpot(type) })
                .presentationDetents([.fraction(0.50), .fraction(0.999)])
                .presentationBackground(.thickMaterial)
                .presentationBackgroundInteraction(.enabled)
                .presentationCornerRadius(14)
        }
        .popover(isPresented: $showingLocationPicker) {
            LocationPicker(lat: $stream.latitude, lng: $stream.longitude)
                .presentationDetents([.fraction(0.50), .fraction(0.999)])
                .presentationBackground(.thickMaterial)
                .presentationBackgroundInteraction(.enabled)
                .presentationCornerRadius(14)
        }
        /*.alert("Add an event", isPresented: $eventAlertShown) {
            TextField("Name", text: $eventName)
            Button("Cancel", role: .cancel) {}
            Button("OK", action: newEvent)
        } message: {
            Text("[This UI is temporary.]")
        }*/
    }
    
    private var eventSelector: some View {
        Menu {
            Button(
                "New Event",
                systemImage: "plus",
                action: { eventAlertShown.toggle() }
            )
            
            Divider()
            
            ForEach(spotEvents) { event in
                Button(
                    event.name,
                    systemImage: stream.event == event ? "checkmark" : "", // TODO: fix
                    action: { addToEvent(event) }
                )
            }
        } label: {
            Image(
                systemName: stream.event == nil ? "calendar.badge.plus" : "calendar"
            )
            Text(stream.event == nil ? "Add to Event" : stream.event!.name)
                .lineLimit(1)
                .font(.system(size: 13))
                .padding(.leading, -3)
        }
    }
    
    private var previouslyDiscovered: some View {
        Button(action: { view.stream = identicalShazamStream }) {
            Image(systemName: "clock.fill")
            Text("Previously \(identicalShazamStream?.place ?? "sometime")")
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
    
    private func newEvent() {
        let event = Event(name: eventName, spot: stream.spot!, shazamStreams: [stream])
        modelContext.insert(event)
    }
    
    private func addToEvent(_ event: Event) {
        // Set or clear event
        stream.event = stream.event == event ? nil : event
    }
    
    private func createSpot(_ type: SpotType) {
        showingSpotSelector = false
        // Create new Spot, insert into modelContext, and open for immediate editing
        let spot = Spot(locationFrom: stream, type: type, streams: [stream], modelContext: modelContext)
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
