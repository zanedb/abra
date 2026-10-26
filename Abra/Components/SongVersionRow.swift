import Kingfisher
import MusicKit
import SwiftUI

struct SongVersionRow: View {
    let song: Song
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            KFImage(song.artwork?.url(width: 112, height: 112))
                .cancelOnDisappear(true)
                .resizable()
                .placeholder { Image(systemName: "music.note").foregroundStyle(.secondary) }
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(song.title)
                        .font(.body)
                        .lineLimit(2)
                    if song.contentRating == .explicit {
                        Image(systemName: "e.square.fill")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Explicit")
                    }
                }
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let album = song.albumTitle {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let duration = song.duration {
                    Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
