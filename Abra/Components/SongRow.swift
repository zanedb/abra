//
//  SongRow.swift
//  Abra
//

import Kingfisher
import SwiftUI

struct SongRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ShazamProvider.self) private var shazam
    @Environment(MusicProvider.self) private var music
    
    var stream: ShazamStream
    
    @State private var confirmationShown = false
    
    private var nowPlaying: Bool { music.nowPlaying == stream.appleMusicID }
    
    var body: some View {
        HStack {
            KFImage(stream.artworkURL)
                .cancelOnDisappear(true)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 3))
                .padding(.trailing, 5)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(stream.title)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(stream.relativeDateTime)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 3)
                
                Text(stream.artist)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 3)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    if let spot = stream.spot {
                        HStack(spacing: 4) {
                            Image(systemName: spot.symbol)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundColor(Color(spot.color))
                            Text(spot.name)
                                .foregroundStyle(.secondary)
                                .font(.system(size: 13))
                        }
                    }
                    
                    Text(stream.cityState)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
            }
        }
        .frame(height: 96)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive, action: { confirmationShown = true })
            
            if let appleMusicURL = stream.appleMusicURL {
                Divider()
                Link(destination: appleMusicURL) {
                    Label("Open in Apple Music", systemImage: "arrow.up.forward.app")
                }
                ShareLink(item: appleMusicURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            
            if let appleMusicID = stream.appleMusicID {
                Divider()
                Button(
                    nowPlaying ? "Pause" : "Play",
                    systemImage: nowPlaying ? "pause.fill" : "play.fill",
                    action: { music.playPause(id: appleMusicID) }
                )
            }
        }
        .confirmationDialog("This song will be deleted from your Abra and Shazam libraries.", isPresented: $confirmationShown, titleVisibility: .visible) {
            Button("Delete Song", role: .destructive, action: deleteStream)
        }
    }
    
    private func deleteStream() {
        withAnimation {
            modelContext.delete(stream)
            try? modelContext.save()
        }
        Task {
            try? await shazam.removeFromLibrary(stream: stream)
        }
    }
}

struct SongRowMini: View {
    @Environment(SheetProvider.self) var view
    @Environment(MusicProvider.self) private var music
    
    var stream: ShazamStream
    
    private var nowPlaying: Bool { music.nowPlaying != nil && music.nowPlaying == stream.appleMusicID }
    private var lastPlayed: Bool { music.lastPlayed != nil && music.lastPlayed == stream.appleMusicID }
    
    var body: some View {
        HStack {
            KFImage(stream.artworkURL)
                .cancelOnDisappear(true)
                .resizable()
                .placeholder { ProgressView() }
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 3))
                .padding(.trailing, 5)
                .overlay {
                    if nowPlaying || lastPlayed {
                        NowPlayingAnimation(on: nowPlaying)
                            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    }
                }
                
            VStack(alignment: .leading) {
                HStack {
                    Text(stream.title)
                        .lineLimit(1)
                    if stream.isExplicit {
                        Image(systemName: "e.square.fill")
                            .imageScale(.small)
                            .foregroundColor(.secondary)
                            .padding(.leading, -3.0)
                            .accessibilityLabel("Explicit")
                    }
                }
                
                Text(stream.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .frame(maxHeight: 44)
        .contextMenu {
            if let appleMusicURL = stream.appleMusicURL {
                Link(destination: appleMusicURL) {
                    Label("Open in Apple Music", systemImage: "arrow.up.forward.app")
                }
                ShareLink(item: appleMusicURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Divider()
            }
            
            Button("View", systemImage: "arrow.up.right", action: { view.show(stream) })
        }
        .contentShape(Rectangle())
    }
}

struct NowPlayingAnimation: View {
    let on: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 5) { index in
                AnimatedBar(
                    isAnimating: on,
                    delay: Double(index) * 0.1
                )
            }
        }
        .frame(width: 48, height: 48)
        .background(.black.opacity(0.4))
        .clipShape(.rect(cornerRadius: 3))
        .padding(.trailing, 5)
    }
}

struct AnimatedBar: View {
    let isAnimating: Bool
    let delay: Double
    
    @State private var height: CGFloat = 2
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(.white)
            .frame(width: 2, height: height)
            .animation(
                isAnimating ?
                    Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay) :
                    Animation.easeInOut(duration: 0.3),
                value: height
            )
            .onAppear {
                updateHeight()
            }
            .onChange(of: isAnimating) {
                updateHeight()
            }
    }
    
    private func updateHeight() {
        if isAnimating {
            // Random heights for the bars when animating
            let heights: [CGFloat] = [8, 12, 16, 10, 6]
            height = heights[Int(delay * 10) % heights.count]
        } else {
            // Collapsed state
            height = 2
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        SongRow(stream: .preview)
            
        Text("Discovered")
            .font(.subheadline)
            .bold()
            .foregroundColor(.gray)
            .padding(.horizontal)
            .padding(.top, 12)
        EditableList(Binding(get: { [ShazamStream.preview, ShazamStream.preview] }, set: { _ in })) { $stream in
            SongRowMini(stream: stream)
        }
        .listStyle(.plain)
    }
    .modelContainer(PreviewSampleData.container)
    .environment(ShazamProvider())
    .environment(SheetProvider())
    .environment(MusicProvider())
}
