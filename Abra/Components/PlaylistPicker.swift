//
//  PlaylistPicker.swift
//  Abra
//

import Kingfisher
import MediaPlayer
import MusicKit
import SwiftUI

struct PlaylistPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    
    var stream: ShazamStream
    
    @State private var searchText = ""
    @State private var loading: MPMediaEntityPersistentID? = nil
    @State private var showingNewPlaylist = false
    @State private var newPlaylistID: MPMediaEntityPersistentID?
    
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
                Button(action: { showingNewPlaylist.toggle() }) {
                    newPlaylistRow
                }
                .buttonStyle(.plain)
                
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
            .sheet(isPresented: $showingNewPlaylist) {
                NewPlaylist(initial: stream, playlistID: $newPlaylistID)
                    .presentationDetents([.fraction(0.999)])
                    .presentationCornerRadius(14)
            }
            .onChange(of: newPlaylistID) {
                if let id = newPlaylistID {
                    showingNewPlaylist = false
                    dismiss()
                    toast.show(message: "Created playlist", type: .success, action: {
                        openURL(URL(string: "music://playlist/\(id)")!)
                    })
                }
            }
        }
    }
    
    private var newPlaylistRow: some View {
        HStack {
            Image(systemName: "music.note.list")
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 6))
                .foregroundStyle(.red)
                .padding(.trailing, 4)
            
            VStack(alignment: .leading) {
                Text("New Playlist")
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
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
                .environment(SheetProvider())
                .environment(MusicProvider())
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
