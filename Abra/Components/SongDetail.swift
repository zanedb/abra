//
//  SongDetail.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SongSelectionKey: PreferenceKey {
    static var defaultValue: ShazamStream? = nil

    static func reduce(value: inout ShazamStream?, nextValue: () -> ShazamStream?) {
        value = nextValue() ?? value
    }
}

struct SongDetail: View {
    @Environment(\.modelContext) var modelContext
    
    @Query var streams: [ShazamStream]
    @State var selected: ShazamStream?
    
    init(stream: ShazamStream) {
        let isrc = stream.isrc
        let id = stream.persistentModelID
        
        // Find instances of the same Shazam via matching ISRC
        let predicate = #Predicate<ShazamStream> {
            $0.isrc == isrc && $0.persistentModelID != id
        }
            
        _streams = Query(filter: predicate, sort: \.timestamp)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            if streams.count > 0 {
                Rectangle()
                    .fill(.background)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 14
                    ))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("You’ve discovered this song before.")
                        .font(.system(size: 16, weight: .medium))
                    
                    HStack(spacing: 4) {
                        Text(streams.first?.description ?? "Sometime, someplace…")
                            .font(.system(size: 14))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.selection)
                }
                .padding()
            }
        }
        .onTapGesture {
            // Pass selection up hierarchy
            selected = streams.first
        }
        .preference(key: SongSelectionKey.self, value: selected)
    }
}
