//
//  PhotoView.swift
//  Abra
//

import LazyPager
import Photos
import SwiftUI

struct PhotoView: View {
    @Environment(LibraryProvider.self) private var library
    @Environment(\.dismiss) private var dismiss

    let photos: [PHAsset]
    @State private var currentIndex: Int
    @State private var imageToShare: Image?
    @State private var opacity: CGFloat = 1
    var onIndexChange: ((Int) -> Void)? = nil

    init(
        photos: [PHAsset],
        initialIndex: Int,
        onIndexChange: ((Int) -> Void)? = nil
    ) {
        self.photos = photos
        self._currentIndex = State(initialValue: initialIndex)
        self.onIndexChange = onIndexChange
    }

    private var currentPhoto: PHAsset? {
        photos.indices.contains(currentIndex) ? photos[currentIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LazyPager(data: photos, page: $currentIndex) { photo in
                    Thumbnail(
                        assetLocalId: photo.localIdentifier,
                        targetSize: CGSize(width: 2048, height: 2048)
                    )
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .zoomable(min: 1, max: 5)
                .onDismiss(backgroundOpacity: $opacity) {
                    dismiss()
                }
                .pageSpacing(10)
                .background(.black.opacity(opacity))
                .background(ClearFullScreenBackground())
                .ignoresSafeArea()
                .onChange(of: currentIndex) { _, new in
                    onIndexChange?(new)
                    imageToShare = nil
                }
                .task(id: currentIndex) {
                    imageToShare = nil
                    guard let photo = currentPhoto,
                        let uiImage = try? await library.fetchImage(
                            byLocalIdentifier: photo.localIdentifier,
                            targetSize: CGSize(width: 2048, height: 2048)
                        )
                    else { return }
                    imageToShare = Image(uiImage: uiImage)
                }
            }
            .toolbar {
                ToolbarItems
            }
        }
    }

    @ToolbarContentBuilder
    private var ToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
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

        ToolbarItem(placement: .confirmationAction) {
            DismissButton(foreground: .white)
        }
    }
}
