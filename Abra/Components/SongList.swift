//
//  SongList.swift
//  Abra
//

import MapKit
import SwiftUI

struct SongList: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: ViewModel
    
    var streams: [ShazamStream]
    @Binding var selection: ShazamStream?
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(streams, id: \.timestamp) { stream in
                        Button(action: { selection = stream }) {
                            SongRowMini(stream: stream)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("\(streams.count) Shazam\(streams.count != 1 ? "s" : "") Selected")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            SongList(streams: [ShazamStream.preview], selection: .constant(nil))
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled)
                .environmentObject(ViewModel())
        }
}
