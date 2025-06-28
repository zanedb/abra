//
//  Thumbnail.swift
//  Abra
//

import SwiftUI
import Photos

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
            ) else {
                image = nil
                return
            }
        image = Image(uiImage: uiImage)
    }
    
    var body: some View {
        ZStack {
            if let image = image {
                GeometryReader { proxy in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.width
                        )
                        .clipped()
                }
                    .aspectRatio(1, contentMode: .fit)
            } else {
                Rectangle()
                    .foregroundColor(.primary)
                    .colorInvert()
                    .aspectRatio(1, contentMode: .fit)
                ProgressView()
            }
        }
            .task {
                await loadImageAsset(targetSize: CGSize(width: 256, height: 256))
            }
            .onDisappear {
                image = nil
            }
    }
}

#Preview {
    Thumbnail(assetLocalId: "")
}
