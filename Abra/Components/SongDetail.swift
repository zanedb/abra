//
//  SongDetail.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SongDetail: View {
    @Environment(\.modelContext) var modelContext
    @Environment(SheetProvider.self) private var view
    
    @Query var streams: [ShazamStream]
    
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
            view.stream = streams.first
        }
    }
}
