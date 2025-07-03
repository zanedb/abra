//
//  Thumbnail.swift
//  Abra
//

import Photos
import SwiftUI

struct Thumbnail: View {
    @Environment(LibraryProvider.self) private var library
    @State private var image: Image?

    var assetLocalId: String

    func loadImageAsset(
        targetSize: CGSize = CGSize(width: 1024, height: 1024)
    ) async {
        guard let uiImage = try? await library
            .fetchImage(
                byLocalIdentifier: assetLocalId,
                targetSize: targetSize
            )
        else {
            image = nil
            return
        }
        image = Image(uiImage: uiImage)
    }

    var body: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .aspectRatio(2/3, contentMode: .fit)
            } else {
                Rectangle()
                    .foregroundColor(.primary)
                    .colorInvert()
                    .aspectRatio(2/3, contentMode: .fit)
                ProgressView()
            }
        }
        .task(id: assetLocalId) {
            await loadImageAsset(targetSize: CGSize(width: 256, height: 384))
        }
        .onDisappear {
            image = nil
        }
    }
}

#Preview {
    Thumbnail(assetLocalId: "")
}
