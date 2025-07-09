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
    @Query var streams: [ShazamStream]
    
    init(stream: ShazamStream) {
        let title = stream.title
        let artist = stream.artist
        let id = stream.persistentModelID
        
        self.stream = stream
        
        // Find instances of the same Shazam via matching title & artist
        let predicate = #Predicate<ShazamStream> {
            $0.title == title && $0.artist == artist && $0.persistentModelID != id
        }
            
        _streams = Query(filter: predicate, sort: \.timestamp)
    }
    
    private var type: SpotType {
        stream.modality == .driving ? .vehicle : .place
    }
    
    @Query(sort: \Spot.updatedAt, order: .reverse)
    private var spots: [Spot]
    
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
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            spotSelector
                            
                            if !streams.isEmpty {
                                Button(
                                    "Previously \(streams.first?.place ?? "sometime")",
                                    systemImage: "arrow.up.right",
                                    action: { view.stream = streams.first }
                                )
                                .font(.system(size: 13))
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
                    systemImage: spot.iconName,
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
        // TODO: ensure it can't be applied to multiple, clicking again removes, etc
        // Replace Menu with Picker?
        stream.spot = spot
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
}
