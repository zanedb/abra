//
//  SongView.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct SongView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(SheetProvider.self) private var view
    @Environment(LibraryProvider.self) private var library
    @Environment(MusicProvider.self) private var music
    
    var stream: ShazamStream
    
    @State private var minimized: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                SongSheet(stream: stream, mini: minimized)
                    .padding(.top, 8)
                    .overlay(alignment: .top) {
                        toolbar
                    }
                
                SongInfo(stream: stream)
                    .padding(.top)
                    .padding(.bottom, 4)
                
                SongDetail(stream: stream)
                
                if !library.hasIgnoredPhotosRequest {
                    HStack {
                        Text(stream.timestamp, style: .date)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(stream.timestamp, style: .time)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    .padding(.bottom, 8)
                    
                    Photos(stream: stream)
                }
                
                Spacer()
            }
        }
        .padding()
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { minimized = ($0.height < 100) ? true : false }
        .task {
            await music.authorize()
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
        .padding(.bottom, 12)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ShazamStream.self, configurations: config)
    
    struct ContentView: View {
        @State private var showSheet = true
        let stream = ShazamStream.preview
        
        var body: some View {
            EmptyView()
                .inspector(isPresented: $showSheet) {
                    SongView(stream: stream)
                        .environment(SheetProvider())
                        .environment(LibraryProvider())
                        .environment(MusicProvider())
                }
        }
    }
    
    return ContentView()
        .modelContainer(container)
}
