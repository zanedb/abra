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
    @State private var offsetY: CGFloat = 0
    
    private var scrolled: Bool {
        offsetY > -50
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                SongSheet(stream: stream, mini: minimized)
                    .padding()
                    .padding(.top, -48)
                
                SongDetail(stream: stream)
                    .padding(.horizontal)
                    
                Photos(stream: stream)
                
                SongActions(stream: stream)
            }
            .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
                geometry.contentOffset.y
            }) { oldValue, newValue in
                if oldValue != newValue {
                    offsetY = newValue
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
                    HStack(spacing: -2) {
                        if let appleMusicURL = stream.appleMusicURL {
                            ShareLink(item: appleMusicURL) {
                                Image(systemName: "square.and.arrow.up.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 24))
                                    .symbolRenderingMode(.hierarchical)
                            }
                        }
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
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
}

#Preview {
    EmptyView()
        .inspector(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
        }
}
