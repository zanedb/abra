//
//  MomentView.swift
//  Abra
//

import Photos
import SwiftUI

struct MomentView: View {
    @Environment(MusicProvider.self) private var music

    var moment: Moment
    var namespace: Namespace.ID

    @Namespace var details

    @State private var selectedPhotoIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                Images
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.all)
            .toolbar {
                ToolbarItems
            }
            .fullScreenCover(
                isPresented: Binding<Bool>(
                    get: { selectedPhotoIndex != nil },
                    set: { _ in selectedPhotoIndex = nil }
                )
            ) {
                PhotoView(
                    photos: moment.phAssets,
                    initialIndex: selectedPhotoIndex!
                )
                .navigationTransition(
                    .zoom(
                        sourceID: moment.phAssets[selectedPhotoIndex!]
                            .localIdentifier,
                        in: details
                    )
                )
            }
        }
        .navigationTransition(
            .zoom(
                sourceID: moment.id,
                in: namespace
            )
        )
    }

    @ToolbarContentBuilder
    private var ToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            DismissButton(foreground: .white)
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Share", systemImage: "square.and.arrow.up") {}
            } label: {
                Image(systemName: "ellipsis")
            }
        }

        /*
        ToolbarItem(placement: .bottomBar) {
            ForEach(moment.streams, id: \.id) { stream in
                SongRowMini(
                    stream: stream,
                    onTapGesture: {
                        if let appleMusicID = stream.appleMusicID {
                            music.playPause(id: appleMusicID)
                        }
                    }
                )
                .padding(.horizontal)
            }
        }
        */
    }

    private var Images: some View {
        VStack(spacing: 2) {
            // First image: full width, 1:1 aspect
            if let firstAsset = moment.phAssets.first {
                Button {
                    selectedPhotoIndex = 0
                } label: {
                    Thumbnail(
                        assetLocalId: firstAsset.localIdentifier,
                        targetSize: .init(width: 512, height: 512)
                    )
                    .scaledToFill()
                    .frame(
                        width: UIScreen.main.bounds.width,
                        height: UIScreen.main.bounds.width
                    )
                    .clipped()
                    .matchedTransitionSource(
                        id: firstAsset.localIdentifier,
                        in: details
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.5),
                            Color.black.opacity(0.25),
                            Color.clear,
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 180)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading) {
                        Text(moment.place)
                            .font(.largeTitle.weight(.bold))
                        Text(
                            "\(moment.timestamp.day) · ^[\(moment.phAssets.count) item](inflect: true)"
                        )
                        .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
            }

            // 3-column grid for remaining images
            let size = (UIScreen.main.bounds.width - (2 * 2)) / 3
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 2),
                    count: 3
                ),
                spacing: 2
            ) {
                ForEach(
                    Array(moment.phAssets.dropFirst().enumerated()),
                    id: \.element
                ) { index, asset in
                    Button {
                        selectedPhotoIndex = index + 1
                    } label: {
                        Thumbnail(
                            assetLocalId: asset.localIdentifier,
                            targetSize: .init(width: 256, height: 256)
                        )
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                        .matchedTransitionSource(
                            id: asset.localIdentifier,
                            in: details
                        )
                        .navigationTransition(
                            .zoom(
                                sourceID: asset.localIdentifier,
                                in: namespace
                            )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

#Preview {
    @Previewable var moment: Moment = .init(
        place: "1015",
        timestamp: .now,
        phAssets: [],
        streams: [.preview]
    )
    @Previewable @Namespace var namespace

    VStack {}
        .fullScreenCover(isPresented: .constant(true)) {
            MomentView(moment: moment, namespace: namespace)
        }
        .environment(SheetProvider())
        .environment(MusicProvider())
}
