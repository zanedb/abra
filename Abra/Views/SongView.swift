//
//  SongView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct SongView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(SheetProvider.self) private var view
    @Environment(LibraryProvider.self) private var library
    @Environment(MusicProvider.self) private var music
    @Environment(LocationProvider.self) private var location
    
    var stream: ShazamStream
    
    @State private var minimized: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                SongSheet(stream: stream, mini: minimized)
                    .padding()
                    .padding(.top, 8)
                    .overlay(alignment: .top) {
                        toolbar
                    }
                
                SongDetail(stream: stream)
                    .padding(.horizontal)
                
                Photos(stream: stream)
                
                Spacer()
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { minimized = ($0.height < 100) ? true : false }
        .task {
            await music.authorize()
        }
        .onChange(of: location.currentPlacemark) {
            // Save location if it wasn't initially ready
            if let currentLoc = location.currentLocation, stream.latitude == -1 && stream.longitude == -1 {
                stream.updateLocation(currentLoc, placemark: location.currentPlacemark)
                stream.spotIt(context: modelContext)
            }
        }
    }
    
    private var toolbar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Spacer()
                
            if stream.appleMusicURL != nil {
                ShareLink(item: stream.appleMusicURL!) {
                    Label("Share", systemImage: "square.and.arrow.up.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundColor(.gray)
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                }
            }
                
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding()
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
