//
//  Thumbnail.swift
//  Abra
//

import Photos
import SwiftUI

struct Thumbnail: View {
    @Environment(LibraryProvider.self) private var library
    @State private var image: Image?

    var assetLocalId: String?
    var targetSize: CGSize = .init(width: 1024, height: 1024)

    func loadImageAsset(
        targetSize: CGSize
    ) async {
        guard let id = assetLocalId,
              let uiImage = try? await library
              .fetchImage(
                  byLocalIdentifier: id,
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
            } else {
                Rectangle()
                    .fill(.clear)
                ProgressView()
            }
        }
        .task(id: assetLocalId) {
            await loadImageAsset(targetSize: targetSize)
        }
        .onDisappear {
            image = nil
        }
    }
}

#Preview {
    Thumbnail(assetLocalId: "")
}
