//
//  SongView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct SongView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationProvider.self) private var location
    
    var stream: ShazamStream
    
    @State private var scrolled = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                SongSheet(stream: stream)
                    .padding()
                    .padding(.top, -50)
                
                SongDetail(stream: stream)
                    
                Photos(stream: stream)
                
                SongActions(stream: stream)
            }
            .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
                geometry.contentOffset.y
            }) { oldValue, newValue in
                if oldValue != newValue {
                    scrolled = newValue > -52
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if scrolled {
                        Text(stream.title)
                            .font(.bigTitle)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: -4) {
                        if let appleMusicURL = stream.appleMusicURL {
                            ShareLink(item: appleMusicURL) {
                                Image(systemName: "square.and.arrow.up.circle.fill")
                                    .foregroundStyle(.gray)
                                    .font(.button)
                                    .symbolRenderingMode(.hierarchical)
                            }
                        }
                        DismissButton()
                    }
                }
            }
        }
        .onChange(of: location.currentPlacemark) {
            // Save location if it wasn't initially ready
            if let currentLoc = location.currentLocation, stream.latitude == -1 && stream.longitude == -1 {
                stream.updateLocation(currentLoc, placemark: location.currentPlacemark)
                stream.spotIt(context: modelContext)
            }
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
}
