//
//  PhotoView.swift
//  Abra

import AVFoundation
import AVKit
import Combine
import LazyPager
import Photos
import SwiftUI

struct PhotoView: View {
    @Environment(LibraryProvider.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [PHAsset]
    var streams: [ShazamStream]
    @State private var currentIndex: Int
    @State private var imageToShare: Image?
    @State private var uiImageToShare: UIImage?
    @State private var videoToShare: URL?
    @State private var currentPlayer: AVPlayer?
    @State private var showVideoControls: Bool = true
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var volumeCancellable: AnyCancellable?
    @State private var opacity: CGFloat = 1
    @State private var showDeleteConfirmation = false
    @State private var showSongInfo = false
    var onIndexChange: ((Int) -> Void)? = nil

    init(
        photos: [PHAsset],
        initialIndex: Int,
        streams: [ShazamStream] = [],
        onIndexChange: ((Int) -> Void)? = nil
    ) {
        self._photos = State(initialValue: photos)
        self._currentIndex = State(initialValue: initialIndex)
        self.streams = streams
        self.onIndexChange = onIndexChange
    }

    private var currentPhoto: PHAsset? {
        photos.indices.contains(currentIndex) ? photos[currentIndex] : nil
    }

    private var currentStream: ShazamStream? {
        guard !streams.isEmpty, let photo = currentPhoto else { return nil }
        let photoDate = photo.creationDate ?? .distantPast
        return streams.min(by: {
            abs($0.timestamp.timeIntervalSince(photoDate))
                < abs($1.timestamp.timeIntervalSince(photoDate))
        })
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                LazyPager(data: photos, page: $currentIndex) { photo in
                    if photo.mediaType == .video {
                        VideoPage(
                            player: photo.localIdentifier
                                == currentPhoto?.localIdentifier
                                ? currentPlayer : nil
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Thumbnail(
                            assetLocalId: photo.localIdentifier,
                            targetSize: CGSize(width: 2048, height: 2048),
                            contentMode: .fit
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .zoomable(onElement: { photo in
                    photo.mediaType == .video
                        ? .disabled
                        : .custom(min: 1, max: 5, doubleTap: .scale(0.5))
                })
                .onDismiss(backgroundOpacity: $opacity) {
                    dismiss()
                }
                .onTap {
                    guard currentPhoto?.mediaType == .video else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showVideoControls.toggle()
                    }
                    if showVideoControls {
                        scheduleControlsHide()
                    } else {
                        controlsHideTask?.cancel()
                    }
                }
                .pageSpacing(10)
                .background(.black.opacity(opacity))
                .background(ClearFullScreenBackground())
                .ignoresSafeArea()
                .onChange(of: currentIndex) { _, new in
                    onIndexChange?(new)
                    currentPlayer?.pause()
                    currentPlayer = nil
                    controlsHideTask?.cancel()
                    volumeCancellable?.cancel()
                    volumeCancellable = nil
                    showVideoControls = true
                    imageToShare = nil
                    uiImageToShare = nil
                    videoToShare = nil
                }
                .task(id: currentIndex) {
                    imageToShare = nil
                    uiImageToShare = nil
                    videoToShare = nil
                    guard let photo = currentPhoto else { return }

                    if photo.mediaType == .video {
                        async let playerItemTask = library.fetchPlayerItem(
                            byLocalIdentifier: photo.localIdentifier
                        )
                        async let videoURLTask = library.fetchVideoURL(
                            byLocalIdentifier: photo.localIdentifier
                        )
                        if let item = try? await playerItemTask {
                            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                            try? AVAudioSession.sharedInstance().setActive(true)
                            let player = AVPlayer(playerItem: item)
                            player.isMuted = true
                            currentPlayer = player
                            player.play()
                            scheduleControlsHide()
                            startVolumeObserver(for: player)
                        }
                        if let url = try? await videoURLTask {
                            videoToShare = url
                        }
                    } else {
                        guard
                            let uiImage = try? await library.fetchImage(
                                byLocalIdentifier: photo.localIdentifier,
                                targetSize: CGSize(width: 2048, height: 2048)
                            )
                        else { return }
                        uiImageToShare = uiImage
                        imageToShare = Image(uiImage: uiImage)
                    }
                }

                // Video control bar — floats above bottom toolbar
                if currentPhoto?.mediaType == .video,
                    let player = currentPlayer, showVideoControls
                {
                    VStack {
                        Spacer()
                        VideoControlBar(player: player)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                            .transition(
                                .opacity.combined(with: .move(edge: .bottom))
                            )
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {}
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
            .sheet(isPresented: $showSongInfo) {
                if let stream = currentStream {
                    SongView(stream: stream)
                }
            }
        }
    }

    private func startVolumeObserver(for player: AVPlayer) {
        volumeCancellable?.cancel()
        volumeCancellable = AVAudioSession.sharedInstance()
            .publisher(for: \.outputVolume)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { _ in
                guard player.isMuted else {
                    volumeCancellable?.cancel()
                    volumeCancellable = nil
                    return
                }
                player.isMuted = false
                volumeCancellable?.cancel()
                volumeCancellable = nil
            }
    }

    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showVideoControls = false
            }
        }
    }

    private func removeCurrentPhoto() {
        guard photos.indices.contains(currentIndex) else { return }
        photos.remove(at: currentIndex)
        if photos.isEmpty {
            dismiss()
        } else if currentIndex >= photos.count {
            currentIndex = photos.count - 1
        }
        imageToShare = nil
        uiImageToShare = nil
        videoToShare = nil
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
        ToolbarItem(placement: .cancellationAction) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
        }

        ToolbarItem(placement: .principal) {
            let date = currentPhoto?.creationDate ?? .distantPast
            let dateStr = date.formatted(.dateTime.month(.wide).day())
            let timeStr = date.formatted(.dateTime.hour().minute())
            let locationLabel: String? = {
                guard let stream = currentStream else { return nil }
                if let spotName = stream.spotName { return spotName }
                if stream.spot != nil {
                    return stream.subLocality ?? stream.city ?? stream.country
                }
                switch (stream.city, stream.subLocality) {
                case let (city?, neighborhood?): return "\(city) - \(neighborhood)"
                case let (city?, nil): return city
                case let (nil, neighborhood?): return neighborhood
                case (nil, nil): break
                }
                return stream.country
            }()
            if #available(iOS 26.0, *) {
                VStack(spacing: 2) {
                    if let locationLabel {
                        Text(locationLabel)
                            .font(.footnote.weight(.semibold))
                    }
                    Text("\(dateStr)  \(timeStr)")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: Capsule())
            } else {
                // Fallback on earlier versions
                // TODO: FIX (or drop os18 support tbh)
                // MARK: CANNOT SHIP AS-IS
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Menu {
                if uiImageToShare != nil {
                    Button {
                        copyCurrentPhoto()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }

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
            } else if let videoToShare {
                ShareLink(
                    item: videoToShare,
                    label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                    }
                )
                .foregroundStyle(.white)
            }
        }

        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }

        // MARK: song pill in bottom?
        /*
         if let stream = currentStream {
            ToolbarItem(placement: .bottomBar) {
                songPill(stream: stream)
            }
        }
         */

        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }

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

    private func songPill(stream: ShazamStream) -> some View {
        Button {
            showSongInfo = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.caption.weight(.semibold))
                VStack(alignment: .leading, spacing: 0) {
                    Text(stream.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(stream.artist)
                        .font(.caption2)
                        .foregroundStyle(.white.secondary)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Previews

#Preview("Photo View") {
    PhotoView(photos: [], initialIndex: 0)
        .environment(LibraryProvider())
}

#Preview("Video Player") {
    struct VideoPreview: View {
        @State private var player: AVPlayer?

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                if let player {
                    VideoPage(player: player)
                        .ignoresSafeArea()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .task {
                // Load first video asset from Photos for a realistic preview
                let options = PHFetchOptions()
                options.fetchLimit = 1
                options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                guard let asset = PHAsset.fetchAssets(with: options).firstObject else { return }
                let library = LibraryProvider()
                if let item = try? await library.fetchPlayerItem(byLocalIdentifier: asset.localIdentifier) {
                    let p = AVPlayer(playerItem: item)
                    p.isMuted = true
                    player = p
                    p.play()
                }
            }
        }
    }
    return VideoPreview()
}
