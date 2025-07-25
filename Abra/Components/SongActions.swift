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
                .clipShape(RoundedRectangle(
                    cornerRadius: 14
                ))

            VStack(alignment: .leading, spacing: 0) {
                if let link = stream.songLink {
                    ShareLink(item: link) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 36, height: 36)
                            .background(.ultraThickMaterial)
                            .clipShape(Circle())
                        
                        Text("Share Song.link")
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    Divider()
                        .padding(.leading, 60)
                }
                
                if stream.appleMusicID != nil {
                    row("Add to Playlist", icon: "music.note.list", action: { showingPlaylistPicker.toggle() })
                
                    Divider()
                        .padding(.leading, 60)
                }
                
                row("Remove", icon: "trash.fill", action: { showingConfirmation = true }, role: .destructive)
            }
        }
        .padding()
        .popover(isPresented: $showingPlaylistPicker) {
            PlaylistPicker(stream: stream)
                .presentationDetents([.fraction(0.50), .fraction(0.999)])
                .presentationBackground(.thickMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.999)))
                .presentationCornerRadius(14)
        }
        .confirmationDialog("This song will be deleted from your Abra and Shazam libraries.", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Delete Song", role: .destructive, action: remove)
        }
    }

    private func row(_ title: String, icon: String, action: @escaping () -> Void, role: ButtonRole? = .none) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
                .frame(width: 36, height: 36)
                .background(.ultraThickMaterial)
                .clipShape(Circle())
            
            Text(title)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
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
