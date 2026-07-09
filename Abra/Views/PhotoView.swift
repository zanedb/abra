//
//  PhotoView.swift
//  Abra

import LazyPager
import Photos
import SwiftUI

struct PhotoView: View {
    @Environment(LibraryProvider.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [PHAsset]
    @State private var currentIndex: Int
    @State private var imageToShare: Image?
    @State private var uiImageToShare: UIImage?
    @State private var opacity: CGFloat = 1
    @State private var showDeleteConfirmation = false
    var onIndexChange: ((Int) -> Void)? = nil

    init(
        photos: [PHAsset],
        initialIndex: Int,
        onIndexChange: ((Int) -> Void)? = nil
    ) {
        self._photos = State(initialValue: photos)
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
                    uiImageToShare = nil
                }
                .task(id: currentIndex) {
                    imageToShare = nil
                    uiImageToShare = nil
                    guard let photo = currentPhoto,
                        let uiImage = try? await library.fetchImage(
                            byLocalIdentifier: photo.localIdentifier,
                            targetSize: CGSize(width: 2048, height: 2048)
                        )
                    else { return }
                    uiImageToShare = uiImage
                    imageToShare = Image(uiImage: uiImage)
                }
            }
            .toolbar {
                ToolbarItems
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .bottomBar)
            .confirmationDialog(
                "Delete Photo?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Photo", role: .destructive) {
                    deleteCurrentPhoto()
                }
            } message: {
                Text("This photo will be deleted from your library.")
            }
        }
    }

    /// Removes the photo at `currentIndex` from the local array,
    /// adjusts the index if needed, and dismisses if the array is empty.
    private func removeCurrentPhoto() {
        guard photos.indices.contains(currentIndex) else { return }
        photos.remove(at: currentIndex)
        if photos.isEmpty {
            dismiss()
        } else if currentIndex >= photos.count {
            currentIndex = photos.count - 1
        }
        // Reset cached image for the new current photo
        imageToShare = nil
        uiImageToShare = nil
    }

    private func copyCurrentPhoto() {
        guard let uiImage = uiImageToShare else { return }
        UIPasteboard.general.image = uiImage
    }

    private func hideCurrentPhoto() {
        guard let photo = currentPhoto else { return }
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: photo)
            request.isHidden = true
        }) { success, _ in
            if success {
                DispatchQueue.main.async {
                    removeCurrentPhoto()
                }
            }
        }
    }

    private func deleteCurrentPhoto() {
        guard let photo = currentPhoto else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([photo] as NSArray)
        }) { success, _ in
            if success {
                DispatchQueue.main.async {
                    removeCurrentPhoto()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var ToolbarItems: some ToolbarContent {
        // Top left — back
        ToolbarItem(placement: .cancellationAction) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
        }

        // Top center — date/time in glassy capsule
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }

        // Top right — ellipsis menu
        ToolbarItem(placement: .confirmationAction) {
            Menu {
                Button {
                    copyCurrentPhoto()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(uiImageToShare == nil)

                Button {
                    hideCurrentPhoto()
                } label: {
                    Label("Hide", systemImage: "eye.slash")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
        }

        // Bottom left — share
        ToolbarItem(placement: .bottomBar) {
            if let imageToShare {
                ShareLink(
                    item: imageToShare,
                    preview: SharePreview("", image: imageToShare),
                    label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                    }
                )
                .foregroundStyle(.white)
            }
        }

        // Bottom center — spacer
        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }

        // Bottom right — delete
        ToolbarItem(placement: .bottomBar) {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
        }
    }
}
