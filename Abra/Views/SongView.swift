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
    @Environment(LibraryProvider.self) private var library
    
    var stream: ShazamStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            
            ScrollView {
                SongSheet(stream: stream)
                
                SongInfo(stream: stream)
                
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
    }
    
    var toolbar: some View {
        HStack(alignment: .center) {
            if stream.appleMusicURL != nil {
                ShareLink(item: stream.appleMusicURL!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                }
            }
            
            Spacer()
            
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
                        .environment(LibraryProvider())
                }
        }
    }
    
    return ContentView()
        .modelContainer(container)
}
