//
//  VideoControls.swift
//  Abra

import AVFoundation
import AVKit
import SwiftUI

// MARK: - VideoPage

struct VideoPage: View {
    let player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                AVPlayerView(player: player)
            } else {
                Color.clear.overlay {
                    ProgressView().tint(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AVPlayerView

struct AVPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        init() {
            super.init(frame: .zero)
            playerLayer.videoGravity = .resizeAspect
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) { fatalError() }

        var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue }
        }
    }
}

// MARK: - VideoControlBar

struct VideoControlBar: View {
    let player: AVPlayer
    @State private var isPlaying = true
    @State private var isMuted = true
    @State private var progress: Double = 0
    @State private var duration: Double = 1
    @State private var isDragging = false
    @State private var wasPlayingBeforeScrub = false

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        if #available(iOS 26.0, *) {
            HStack(spacing: 14) {
                Button {
                    handlePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 20)
                }
                
                Slider(value: $progress, in: 0...1) { editing in
                    if editing {
                        wasPlayingBeforeScrub = isPlaying
                        player.pause()
                        isDragging = true
                    } else {
                        isDragging = false
                        let time = CMTime(
                            seconds: progress * duration,
                            preferredTimescale: 600
                        )
                        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                        if wasPlayingBeforeScrub {
                            player.play()
                        }
                        isPlaying = wasPlayingBeforeScrub
                    }
                }
                .tint(.white)
                
                Button {
                    isMuted.toggle()
                    player.isMuted = isMuted
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 20)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: Capsule())
            .onReceive(ticker) { _ in
                guard !isDragging else { return }
                if let item = player.currentItem {
                    let dur = item.duration.seconds
                    if dur.isFinite, dur > 0 {
                        duration = dur
                        progress = player.currentTime().seconds / dur
                    }
                }
                isPlaying = player.rate != 0
                isMuted = player.isMuted
            }
            .onAppear {
                isPlaying = player.rate != 0
                isMuted = player.isMuted
                if let item = player.currentItem {
                    let dur = item.duration.seconds
                    if dur.isFinite, dur > 0 {
                        duration = dur
                        progress = player.currentTime().seconds / dur
                    }
                }
            }
        } else {
            // Fallback on earlier versions
            // TODO: FIX (or drop os18 support tbh)
            // MARK: CANNOT SHIP AS-IS
        }
    }

    private func handlePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if progress >= 1.0 {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            player.play()
            isPlaying = true
        }
    }

}
