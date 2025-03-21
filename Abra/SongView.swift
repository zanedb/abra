//
//  SongView.swift
//  Abra
//

import SwiftUI
import MapKit
import SwiftData

struct SongView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: ViewModel
    @EnvironmentObject private var library: LibraryService
    
    var stream: ShazamStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            
            SongSheet(stream: stream)
            
            if (!library.hasIgnoredPhotosRequest) {
                HStack {
                    Text(stream.timestamp, style: .date)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(stream.timestamp, style: .time)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                    .padding(.top)
                    .padding(.bottom, 8)
                
                Photos(stream: stream)
            }
            
            Spacer()
        }
            .padding()
    }
    
    var toolbar: some View {
        HStack(alignment: .center) {
            if (stream.appleMusicURL != nil) {
                ShareLink(item: stream.appleMusicURL!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                }
            }
            
            Spacer()
            
            Button { dismiss() } label: {
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
                        .environmentObject(ViewModel())
                        .environmentObject(LibraryService())
                }
        }
    }
    
    return ContentView()
        .modelContainer(container)
}
