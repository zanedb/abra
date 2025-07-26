//
//  PlaylistPicker.swift
//  Abra
//

import MediaPlayer
import MusicKit
import SwiftUI

struct PlaylistPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastProvider) private var toast
    
    var stream: ShazamStream
    
    @State private var searchText = ""
    @State private var loading: MPMediaEntityPersistentID? = nil
    
    private var allPlaylists: [MPMediaPlaylist] = []
    private var playlists: [MPMediaPlaylist] {
        searchText.isEmpty ? allPlaylists : allPlaylists.filter { $0.name!.localizedCaseInsensitiveContains(searchText) }
    }
    
    init(stream: ShazamStream) {
        self.stream = stream
        
        allPlaylists = MPMediaQuery.playlists().collections as? [MPMediaPlaylist] ?? []
        // Filter out smart, Genius, onTheGo playlists
        allPlaylists = allPlaylists.filter { $0.playlistAttributes.rawValue == 0 }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(playlists.isEmpty ? "" : "All Playlists")
                        .font(.subheading)
                        .padding()
                    
                    ForEach(playlists, id: \.persistentID) { playlist in
                        Button(action: { addToPlaylist(playlist) }) {
                            PlaylistRow(playlist)
                        }
                        .buttonStyle(.plain)
                        
                        if playlist != playlists.last {
                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                }
            }
            .navigationTitle("Add to a Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find in Playlists")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
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
    
    private func PlaylistRow(_ playlist: MPMediaPlaylist) -> some View {
        HStack {
            ZStack {
                if let cover = playlist.userImage {
                    Image(uiImage: cover)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(.rect(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.quinary)
                }
                
                if loading == playlist.persistentID {
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.thickMaterial)
                        
                    ProgressView()
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.trailing, 4)
            
            VStack(alignment: .leading) {
                Text(playlist.name ?? "")
                    .font(.headline)
                    .lineLimit(1)
                if let desc = playlist.descriptionText, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private func addToPlaylist(_ playlist: MPMediaPlaylist) {
        withAnimation {
            loading = playlist.persistentID
        }
        
        playlist.addItem(withProductID: stream.appleMusicID!) { error in
            dismiss()
            if error != nil {
                toast.show(message: "Cannot access playlist", type: .error)
            } else {
                toast.show(message: "1 song added", type: .success)
            }
        }
    }
}

#Preview {
    @Previewable @State var stream: ShazamStream = .preview
    
    VStack {}
        .popover(isPresented: .constant(true)) {
            PlaylistPicker(stream: stream)
                .presentationDetents([.fraction(0.999)])
                .presentationBackground(.thickMaterial)
                .modelContainer(PreviewSampleData.container)
        }
}

// https://stackoverflow.com/a/61010669
extension MPMediaPlaylist {
    /**
     User selected image for playlist stored on disk.
     */
    var userImage: UIImage? {
        guard let catalog = value(forKey: "artworkCatalog") as? NSObject else {
            return nil
        }

        let sel = NSSelectorFromString("bestImageFromDisk")

        guard catalog.responds(to: sel),
              let value = catalog.perform(sel)?.takeUnretainedValue(),
              let image = value as? UIImage
        else {
            return nil
        }
        return image
    }

    /**
     URL for playlist's image.
     */
    var imageUrl: URL? {
        if let catalog = value(forKey: "artworkCatalog") as? NSObject,
           let token = catalog.value(forKey: "token") as? NSObject,
           let url = token.value(forKey: "availableArtworkToken") as? String
        {
            return URL(string: "https://is2-ssl.mzstatic.com/image/thumb/\(url)/260x260cc.jpg")
        }
        return nil
    }
}
