//
//  SongInfo.swift
//  Abra
//

import MusicKit
import SwiftData
import SwiftUI

struct SongInfo: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music
    @Environment(SheetProvider.self) private var sheet

    var stream: ShazamStream

    @Query var matchedArtistStreams: [ShazamStream]

    init(stream: ShazamStream) {
        self.stream = stream

        // Find instances of the matching artist
        let artist = stream.artist
        let predicate = #Predicate<ShazamStream> {
            $0.artist == artist
        }
        _matchedArtistStreams = Query(filter: predicate, sort: \.timestamp)
    }

    @State private var albumTitle: String = "Apple vs. 7G"
    @State private var released: String = "2021"
    @State private var genre: String = "Electronic"
    @State private var loadedMetadata: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let appleMusicURL = stream.appleMusicURL,
                let appleMusicID = stream.appleMusicID
            {
                HStack {
                    Button {
                        openURL(appleMusicURL)
                    } label: {
                        Label(
                            "Open in Music",
                            systemImage: "arrow.up.right"
                        )
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .fontWeight(.medium)
                    .adaptiveGlass(
                        prominent: true,
                        tint:
                            LinearGradient(
                                colors: [.red.opacity(0.8), .red.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )

                    Button {
                        music.playPause(id: appleMusicID)
                    } label: {
                        Label(
                            music.nowPlaying == appleMusicID
                                ? "Pause" : "Play",
                            systemImage: music.nowPlaying == appleMusicID
                                ? "pause.fill" : "play.fill"
                        )
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(.link)
                    .adaptiveGlass()
                }
                .padding(.top, -12)
                .padding(.bottom)
            }

            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Album")
                        .font(.caption.weight(.medium))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(albumTitle)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Genre")
                        .font(.caption.weight(.medium))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(genre)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Released")
                        .font(.caption.weight(.medium))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(released)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .redacted(reason: loadedMetadata ? [] : .placeholder)
                }
            }

            if matchedArtistStreams.count > 1 {
                Wrapper {
                    Button {
                        sheet.searchText = stream.artist
                        dismiss()
                    } label: {
                        Image(systemName: "list.bullet.indent")
                            .foregroundStyle(.link)
                        Text(
                            "^[\(matchedArtistStreams.count) song](inflect: true) by \(stream.artist) in library."
                        )
                        .foregroundStyle(.link)
                        .lineLimit(1)
                        Spacer()
                    }
                    .font(.callout)
                }
                .padding(.top, 12)
            }
        }
        .padding()
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
