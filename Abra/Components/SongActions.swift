//
//  SongActions.swift
//  Abra
//

import SwiftUI

struct SongActions: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ShazamProvider.self) private var shazam
    
    @Bindable var stream: ShazamStream
    
    @State private var showingConfirmation = false
    @State private var showingPlaylistPicker = false

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(.background)
                .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 0) {
                if let link = stream.songLink {
                    ShareLink(item: link) {
                        rowContent("Share Song.link", icon: "square.and.arrow.up")
                    }
                    
                    Divider()
                        .padding(.leading, 56)
                }
                
                if stream.appleMusicID != nil {
                    Button(action: { showingPlaylistPicker.toggle() }) {
                        rowContent("Add to Playlist", icon: "music.note.list")
                    }
                
                    Divider()
                        .padding(.leading, 56)
                }
                
                Button(role: .destructive, action: { showingConfirmation = true }) {
                    rowContent("Delete", icon: "trash.fill")
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom)
        .popover(isPresented: $showingPlaylistPicker) {
            PlaylistPicker(stream: stream)
                .presentationDetents([.large])
                .presentationBackground(.thickMaterial)
                .presentationCornerRadius(14)
        }
        .confirmationDialog("This song will be deleted from your Abra and Shazam libraries.", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Delete Song", role: .destructive, action: remove)
        }
    }
    
    private func rowContent(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 32, height: 32)
                .background(.thinMaterial)
                .clipShape(Circle())
                .font(.system(size: 16))
            
            Text(title)
                .font(.callout)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func remove() {
        withAnimation {
            modelContext.delete(stream)
            try? modelContext.save()
        }
        Task {
            try? await shazam.removeFromLibrary(stream: stream)
        }
        dismiss()
    }
}

#Preview {
    ScrollView {
        SongActions(stream: .preview)
            .environment(ShazamProvider())
            .modelContainer(PreviewSampleData.container)
    }
    .background(.thickMaterial)
}
