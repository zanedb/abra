//
//  PhotoView.swift
//  Abra
//

import Photos
import SwiftUI

struct PhotoView: View {
    @Environment(LibraryProvider.self) private var library

    let photos: [PHAsset]

    @State private var currentIndex: Int
    @State private var imageToShare: Image?

    init(photos: [PHAsset], initialIndex: Int) {
        self.photos = photos
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationStack {
            Photo
                .ignoresSafeArea()
                .background(.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItems
                }
        }
    }

    @ToolbarContentBuilder
    private var ToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            DismissButton(foreground: .white)
        }

        ToolbarItem(placement: .principal) {
            VStack {
                Text(
                    photos[currentIndex].creationDate ?? .distantPast,
                    style: .date
                )
                .font(.caption)

                Text(
                    photos[currentIndex].creationDate ?? .distantPast,
                    style: .time
                )
                .font(.callout.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.primary)
            .background(.regularMaterial, in: Capsule())
        }

        ToolbarItem(placement: .primaryAction) {
            if let imageToShare {
                ShareLink(
                    item: imageToShare,
                    preview: SharePreview("", image: imageToShare),
                    label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                )
                .backportCircleSymbolVariant(fill: false)
            }
        }
    }

    private var Photo: some View {
        TabView(selection: $currentIndex) {
            ForEach(photos.indices, id: \.self) { index in
                GeometryReader { geometry in
                    Thumbnail(
                        assetLocalId: photos[index].localIdentifier,
                        targetSize: .init(width: 1024, height: 1024),
                        callback: { image in
                            imageToShare = Image(uiImage: image)
                        }
                    )
                    .scaledToFit()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
}
