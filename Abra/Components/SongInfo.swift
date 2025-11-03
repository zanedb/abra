//
//  SongInfo.swift
//  Abra
//

import MusicKit
import SwiftUI

struct SongInfo: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music

    var stream: ShazamStream

    @State private var albumTitle: String = "Apple vs. 7G"
    @State private var released: String = "2021"
    @State private var genre: String = "Electronic"
    @State private var loadedMetadata: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            
            HStack {
                Button {
                    if let url = stream.appleMusicURL {
                        openURL(url)
                    }
                } label: {
                    Text("Open in Apple Music")
                        .lineLimit(1)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .disabled(stream.appleMusicURL == nil)
                .fontWeight(.medium)
                .background(.link)
                .foregroundStyle(.background)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Button {
                    if let url = stream.songLink {
                        openURL(url)
                    }
                } label: {
                    Text("Song.link")
                        .padding(.horizontal)
                        .padding()
                }
                .disabled(stream.appleMusicURL == nil)
                .fontWeight(.medium)
                .background(.bar)
                .foregroundStyle(.link)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            HStack(spacing: 6) {
                VStack(alignment: .leading) {
                    Text("Album")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(albumTitle)
                        .lineLimit(1)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Genre")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(genre)
                        .lineLimit(1)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Released")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(released)
                        .lineLimit(1)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                }
            }
            .padding(.top)
        }
        .padding()
//        .padding(.top, -56)
        .frame(maxWidth: .infinity, alignment: .center)
        .task(id: stream.persistentModelID, loadMetadata)

    }

    @Sendable private func loadMetadata() async {
        guard let id = stream.appleMusicID else {
            loadedMetadata = false
            return
        }

        do {
            let song = try await music.fetchTrackInfo(id)

            if let albumName = song?.albumTitle,
                let releaseDate = song?.releaseDate?.year,
                let genres = song?.genreNames
            {
                albumTitle =
                    albumName.hasSuffix(" - Single") ? "Single" : albumName
                genre = genres.first ?? ""
                released = releaseDate

                loadedMetadata = true
            }
        } catch {
            loadedMetadata = false  // Don't show stale information

            var message = error.localizedDescription
            if let e = error as? MusicDataRequest.Error {
                message = e.title
            }

            toast.show(
                message: message,
                type: .error,
                symbol: "exclamationmark.circle.fill",
                action: message == "Permission denied"
                    ? {
                        // On permissions issue, tapping takes you right to app settings!
                        openURL(
                            URL(string: UIApplication.openSettingsURLString)!
                        )
                    } : nil
            )
        }
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            SongView(stream: .preview)
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
}
