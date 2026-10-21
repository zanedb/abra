//
//  MomentAssetBadges.swift
//  Abra
//

import Photos
import SwiftUI

struct MomentAssetBadges: View {
    let asset: PHAsset

    var body: some View {
        HStack(alignment: .bottom) {
            if asset.isFavorite {
                Image(systemName: "heart.fill")
                    .accessibilityLabel("Favorite")
            }
            Spacer(minLength: 4)
            if asset.mediaType == .video {
                Text(Duration.seconds(asset.duration).formatted(.time(pattern: .minuteSecond)))
                    .monospacedDigit()
                    .accessibilityLabel("Video duration")
                    .accessibilityValue(Duration.seconds(asset.duration).formatted(.time(pattern: .minuteSecond)))
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .shadow(color: .black, radius: 2)
        .padding(8)
        .background(alignment: .bottom) {
            if asset.mediaType == .video || asset.isFavorite {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
    }
}
