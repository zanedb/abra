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
    @Environment(MusicProvider.self) private var music
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [PHAsset]
    var streams: [ShazamStream]
    @State private var currentIndex: Int
    @State private var imageToShare: Image?
    @State private var uiImageToShare: UIImage?
    @State private var videoToShare: URL?
    @State private var currentPlayer: AVPlayer?
    @State private var isViewerVisible = true
    @State private var hasExclusiveVideoAudioSession = false
    @State private var showVideoControls: Bool = true
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var volumeCancellable: AnyCancellable?
    @State private var opacity: CGFloat = 1
    @State private var showDeleteConfirmation = false
    @State private var showSongInfo = false
    @State private var isUpdatingFavorite = false
    @State private var showFavoriteError = false
    var onIndexChange: ((Int) -> Void)? = nil
    var onAssetChange: ((PHAsset) -> Void)? = nil

    init(
        photos: [PHAsset],
        initialIndex: Int,
        streams: [ShazamStream] = [],
        onIndexChange: ((Int) -> Void)? = nil,
        onAssetChange: ((PHAsset) -> Void)? = nil
    ) {
        self._photos = State(initialValue: photos)
        self._currentIndex = State(initialValue: initialIndex)
        self.streams = streams
        self.onIndexChange = onIndexChange
        self.onAssetChange = onAssetChange
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
                .zoomable(min: 1, max: 5)
                .onDismiss(backgroundOpacity: $opacity) {
                    dismissViewer()
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
                }
                .onChange(of: currentPhoto?.localIdentifier) {
                    stopVideoPlayback()
                    showVideoControls = true
                }
                .task(id: currentPhoto?.localIdentifier) {
                    await loadCurrentPhoto()
                }

                // Video control bar — floats above bottom toolbar
                if currentPhoto?.mediaType == .video,
                    let player = currentPlayer, showVideoControls
                {
                    VStack {
                        Spacer()
                        VideoControlBar(player: player, onMuteChange: setVideoMuted)
                            .id(ObjectIdentifier(player))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                            .transition(
                                .opacity.combined(with: .move(edge: .bottom))
                            )
                    }
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
            .alert("Couldn’t Update Favorite", isPresented: $showFavoriteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
        }
        .onAppear { isViewerVisible = true }
        .onDisappear {
            isViewerVisible = false
            stopVideoPlayback()
        }
    }

    private func loadCurrentPhoto() async {
        guard isViewerVisible, !Task.isCancelled, let photo = currentPhoto else { return }
        stopVideoPlayback()
        imageToShare = nil
        uiImageToShare = nil
        videoToShare = nil
        let identifier = photo.localIdentifier

        if photo.mediaType == .video {
            async let playerItemTask = library.fetchPlayerItem(byLocalIdentifier: identifier)
            async let videoURLTask = library.fetchVideoURL(byLocalIdentifier: identifier)
            if let item = try? await playerItemTask {
                // PhotoKit requests can finish after their SwiftUI task is cancelled.
                guard canUseLoadedAsset(identifier) else { return }
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
                    try session.setActive(true)
                } catch {
                    // Do not risk interrupting music if mixing could not be configured.
                    return
                }
                let player = AVPlayer(playerItem: item)
                player.isMuted = true
                currentPlayer = player
                player.play()
                scheduleControlsHide()
                startVolumeObserver(for: player)
            }
            if let url = try? await videoURLTask {
                guard canUseLoadedAsset(identifier) else { return }
                videoToShare = url
            }
        } else {
            guard let uiImage = try? await library.fetchImage(
                byLocalIdentifier: identifier,
                targetSize: CGSize(width: 2048, height: 2048)
            ), canUseLoadedAsset(identifier) else { return }
            uiImageToShare = uiImage
            imageToShare = Image(uiImage: uiImage)
        }
    }

    private func canUseLoadedAsset(_ identifier: String) -> Bool {
        !Task.isCancelled && isViewerVisible && currentPhoto?.localIdentifier == identifier
    }

    private func dismissViewer() {
        isViewerVisible = false
        stopVideoPlayback()
        dismiss()
    }

    private func stopVideoPlayback() {
        controlsHideTask?.cancel()
        controlsHideTask = nil
        volumeCancellable?.cancel()
        volumeCancellable = nil
        currentPlayer?.pause()
        currentPlayer?.isMuted = true
        currentPlayer?.replaceCurrentItem(with: nil)
        currentPlayer = nil
        if hasExclusiveVideoAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            hasExclusiveVideoAudioSession = false
        }
    }

    private func setVideoMuted(_ muted: Bool) {
        guard isViewerVisible, let player = currentPlayer else { return }
        if muted {
            player.isMuted = true
            // Release exclusive audio before continuing silent playback.
            let wasPlaying = player.rate != 0
            player.pause()
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            hasExclusiveVideoAudioSession = false
            do {
                try session.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
                try session.setActive(true)
                if wasPlaying { player.play() }
            } catch {
                return
            }
        } else {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .moviePlayback)
                hasExclusiveVideoAudioSession = true
                try session.setActive(true)
                music.stopPreviewPlayback()
                music.stopPlayback()
                player.isMuted = false
            } catch {
                // Leave the player muted if exclusive audio could not be acquired.
                return
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
                guard isViewerVisible, currentPlayer === player else { return }
                guard player.isMuted else {
                    volumeCancellable?.cancel()
                    volumeCancellable = nil
                    return
                }
                setVideoMuted(false)
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
        stopVideoPlayback()
        photos.remove(at: currentIndex)
        if photos.isEmpty {
            dismissViewer()
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

    private func toggleCurrentPhotoFavorite() {
        guard let photo = currentPhoto, !isUpdatingFavorite else { return }
        isUpdatingFavorite = true
        let identifier = photo.localIdentifier
        let isFavorite = !photo.isFavorite

        Task {
            defer { isUpdatingFavorite = false }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest(for: photo).isFavorite = isFavorite
                }
                let updatedPhoto = try await library.fetchAsset(byLocalIdentifier: identifier)
                if let index = photos.firstIndex(where: { $0.localIdentifier == identifier }) {
                    photos[index] = updatedPhoto
                }
                onAssetChange?(updatedPhoto)
            } catch {
                showFavoriteError = true
            }
        }
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
            Button(action: dismissViewer) {
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
                ControlGroup {
                    Button("Copy", systemImage: "doc.on.doc", action: copyCurrentPhoto)
                        .disabled(uiImageToShare == nil)

                    if let photo = currentPhoto {
                        Button(
                            photo.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: photo.isFavorite ? "heart.slash" : "heart",
                            action: toggleCurrentPhotoFavorite
                        )
                        .disabled(isUpdatingFavorite)
                    }

                    Button("Hide", systemImage: "eye.slash", action: hideCurrentPhoto)
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
        .environment(MusicProvider())
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
