//
//  SongDetail.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SongDetail: View {
    @Environment(\.modelContext) var modelContext
    @Environment(SheetProvider.self) private var view
    
    private var stream: ShazamStream
    
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
        identicalShazamStreams.first // TODO: determine if .first makes sense
    }
    
    @State private var eventAlertShown = false
    @State private var eventName = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Discovered")
                .foregroundColor(.gray)
                .bold()
                .font(.system(size: 15))
        
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.background)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 14
                    ))
                
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            spotSelector
                                .padding(.bottom, 4)
                            
                            if stream.spot != nil {
                                eventSelector
                            }
                            
                            if !identicalShazamStreams.isEmpty {
                                previouslyDiscovered
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(stream.timestamp, style: .time)
                                .font(.system(size: 13))
                                .bold()
                                .foregroundColor(.secondary)
                            Text(stream.timestamp, style: .date)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .alert("Add an event", isPresented: $eventAlertShown) {
            TextField("Name", text: $eventName)
            Button("Cancel", role: .cancel) {}
            Button("OK", action: newEvent)
        } message: {
            Text("[This UI is temporary.]")
        }
    }
    
    private var spotSelector: some View {
        Menu {
            Button(
                "New \(type == .place ? "Spot" : "Vehicle")",
                systemImage: "plus",
                action: { newSpot(type) }
            )
            
            Divider()
            
            ForEach(spots) { spot in
                Button(
                    spot.name,
                    systemImage: stream.spot == spot ? "checkmark" : spot.iconName,
                    action: { addToSpot(spot) }
                )
            }
        } label: {
            Image(
                systemName: stream.spot == nil
                    ? (type == .place ? "mappin.and.ellipse" : "car.fill")
                    : stream.spot!.iconName
            )
            Text(stream.spot == nil ? "Select" : stream.spot!.name)
                .lineLimit(1)
                .fontWeight(.medium)
                .padding(.leading, -3)
        }
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
    
    private func newSpot(_ type: SpotType) {
        // Dismiss song sheet
        let selected = view.stream
        view.stream = nil
           
        // Create new Spot, insert into modelContext, and open for immediate editing
        let spot = Spot(locationFrom: selected!, type: type, streams: [selected!], modelContext: modelContext)
        modelContext.insert(spot)
        view.spot = spot
    }
    
    private func addToSpot(_ spot: Spot) {
        // Set or clear spot
        stream.spot = stream.spot == spot ? nil : spot
    }
    
    private func newEvent() {
        let event = Event(name: eventName, spot: stream.spot!, shazamStreams: [stream])
        modelContext.insert(event)
    }
    
    private func addToEvent(_ event: Event) {
        // Set or clear event
        stream.event = stream.event == event ? nil : event
    }
}

#Preview {
    EmptyView()
        .inspector(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
        }
        .modelContainer(PreviewSampleData.container)
}
