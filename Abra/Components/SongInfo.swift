//
//  SongInfo.swift
//  Abra
//

import Kingfisher
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
    var expansion: CGFloat  // amount from 0-1

    @Query var matchedArtistStreams: [ShazamStream]

    init(stream: ShazamStream, expansion: CGFloat) {
        self.stream = stream
        self.expansion = expansion

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
        VStack(alignment: .center, spacing: 0) {
            Heading

            if let appleMusicURL = stream.appleMusicURL,
                let appleMusicID = stream.appleMusicID
            {
                HStack {
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
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .center)
        .task(id: stream.persistentModelID, loadMetadata)

    }

    private var Heading: some View {
        let t = smooth(expansion)
        let gatedT = remapHalfRange(t)
        let opacity = CGFloat(lerp(-0.25, 1, t))
        let imagePadding = CGFloat(lerp(-144, 16, t))
        let imageScale = CGFloat(lerp(0.5, 1, gatedT))
        let titleFontSize = CGFloat(lerp(20, 22, t))  // .title3 -> .title2
        let artistFontSize = CGFloat(lerp(13, 20, t))  // .footnote -> .title3
        let maxWidth = CGFloat(lerp(230, 350, t))
        let descMaxWidth = CGFloat(lerp(0, 275, gatedT))
        let descPadding = CGFloat(lerp(0, 16, t))
        let topPadding = CGFloat(lerp(-52, 8, t))

        return VStack(alignment: .center, spacing: 0) {
            KFImage(stream.artworkURL)
                .cancelOnDisappear(true)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: 144, height: 144)
                .clipShape(.rect(cornerRadius: 18))
                .padding(.bottom, imagePadding)
                .opacity(opacity)
                .scaleEffect(imageScale)

            Text(stream.title)
                .font(
                    .system(
                        size: titleFontSize,
                        weight: expansion > 0.5 ? .bold : .semibold
                    )
                )
                .lineLimit(1)
                .frame(maxWidth: maxWidth)
            Button {
                sheet.searchText = stream.artist
                dismiss()
            } label: {
                Text(stream.artist)
                    .lineLimit(1)
                // If other Shazams by artist exist, indicate via icon
                if matchedArtistStreams.count > 1 && expansion > 0.5 {
                    Text("\(matchedArtistStreams.count)")
                        .font(.footnote)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(Capsule())
                        .padding(.leading, -2)
                }
            }
            .font(
                .system(
                    size: artistFontSize,
                    weight: expansion > 0.5 ? .medium : .regular
                )
            )
            .foregroundStyle(expansion > 0.5 ? .red : .secondary)
            .padding(.top, expansion > 0.5 ? 2 : 0)
            .frame(maxWidth: maxWidth)

            if loadedMetadata {
                HStack(spacing: 4) {
                    Text(genre)
                        .foregroundStyle(.secondary)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.weight(.medium))
                    Text(released)
                        .foregroundStyle(.secondary)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                .padding(.top, 4)
                .padding(.bottom, descPadding)
                .frame(maxWidth: descMaxWidth)
            }
        }
        .padding(.bottom, descPadding)
        .padding(.top, topPadding)
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
                .presentationDetents([.medium, .large])
                .environment(SheetProvider())
                .environment(LibraryProvider())
                .environment(MusicProvider())
                .environment(LocationProvider())
                .environment(ShazamProvider())
        }
}
