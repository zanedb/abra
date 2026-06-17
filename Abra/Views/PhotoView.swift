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

    var onIndexChange: ((Int) -> Void)? = nil

    init(photos: [PHAsset], initialIndex: Int, onIndexChange: ((Int) -> Void)? = nil) {
        self.photos = photos
        self._currentIndex = State(initialValue: initialIndex)
        self.onIndexChange = onIndexChange
    }

    private var currentPhoto: PHAsset? {
        photos.indices.contains(currentIndex) ? photos[currentIndex] : nil
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
                    currentPhoto?.creationDate ?? .distantPast,
                    style: .date
                )
                .font(.caption)

                Text(
                    currentPhoto?.creationDate ?? .distantPast,
                    style: .time
                )
                .font(.callout.weight(.medium))
            }
            .foregroundStyle(.white)
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
        .onChange(of: currentIndex) { _, new in onIndexChange?(new) }
    }
}
