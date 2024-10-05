//
//  SongView.swift
//  abra
//
//  Created by Zane on 6/19/23.
//

import SwiftUI
import MapKit
import SDWebImageSwiftUI
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
            
            card
            
            if (!library.hasIgnoredPhotosRequest) {
                Text("Moments")
                    .font(.headline)
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
            ShareLink(item: stream.appleMusicURL!) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20))
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
    
    var card: some View {
        HStack(alignment: .top) {
            WebImage(url: stream.artworkURL)
                .resizable()
                .placeholder {
                    ProgressView()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .padding(.trailing, 5)
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(3.0)
                .padding(.trailing, 5)
            VStack(alignment: .leading, spacing: 0) {
                Text(stream.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.80) : Color.black.opacity(0.80))
                    .font(.system(size: 17))
                    .padding(.bottom, 3)
                    .lineLimit(1)
                Text(stream.artist)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                    .font(.system(size: 14))
                    .padding(.bottom, 3)
                    .lineLimit(1)
                Text(stream.definiteDateAndTime)
                    .foregroundColor(Color.gray)
                    .font(.system(size: 13))
                Spacer()
                
                PlayButton(appleMusicID: stream.appleMusicID ?? "1486262969")
            }
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ShazamStream.self, configurations: config)

    let s = ShazamStream.preview
    return SongView(stream: s)
        .modelContainer(container)
        .environmentObject(ViewModel())
}
