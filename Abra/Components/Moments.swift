//
//  Moments.swift
//  Abra
//

import Photos
import SwiftData
import SwiftUI

struct Moment: Identifiable {
    var id = UUID()
    var place: String
    var timestamp: Date
    var phAssets: [PHAsset] = []
    var streams: [ShazamStream] = []
}

struct Moments: View {
    @Environment(LibraryProvider.self) private var library
    @Environment(\.openURL) private var openURL

    @AppStorage("hasRequestedPhotosAuthorization") var requestedAuthorization:
        Bool = false
    @AppStorage("hasIgnoredPhotosRequest") var ignoredRequest: Bool = false

    @Namespace var transitionNamespace

    init(stream: ShazamStream) {
        self.stream = stream
        self.id = stream.id
    }

    init(spot: Spot) {
        self.spot = spot
        self.id = spot.id
    }

    var stream: ShazamStream?
    var spot: Spot?
    var id: PersistentIdentifier

    private enum FullScreenItem: Identifiable {
        case moment(Moment)
        case photos([PHAsset], [ShazamStream])

        var id: String {
            switch self {
            case .moment(let m): m.id.uuidString
            case .photos(let assets, _): assets.map(\.localIdentifier).joined()
            }
        }
    }

    @State private var moments: [Moment] = []
    @State private var fullScreenItem: FullScreenItem? = nil

    private func loadPhotos() {
        // Request authorization, on success load photos
        // THIS IS INSANE, RE-DO!
        library.requestAuthorization {
            if library.authorized {
                var streams: [ShazamStream] = []
                if let stream {
                    streams.append(stream)
                } else if let spot {
                    spot.shazamStreams?.forEach { streams.append($0) }
                }

                // Group streams by date and location to avoid duplicate moments
                var momentDict: [String: Moment] = [:]

                for stream in streams {
                    let photos = library.fetchSelectedPhotos(
                        date: stream.timestamp,
                        location: stream.location
                    )
                    guard !photos.isEmpty else { continue }

                    // Create a key based on date (day) and place to group similar moments
                    let calendar = Calendar.current
                    let dayComponent = calendar.startOfDay(
                        for: stream.timestamp
                    )
                    let key =
                        "\(stream.place)_\(dayComponent.timeIntervalSince1970)"

                    if var existingMoment = momentDict[key] {
                        // Add this stream to existing moment if photos are the same
                        let existingPhotoIds = Set(
                            existingMoment.phAssets.map(\.localIdentifier)
                        )
                        let newPhotoIds = Set(photos.map(\.localIdentifier))

                        if existingPhotoIds == newPhotoIds {
                            // Same photos, just add the stream
                            existingMoment.streams.append(stream)
                            momentDict[key] = existingMoment
                        } else {
                            // Different photos, create new moment
                            let newMoment = Moment(
                                place: stream.place,
                                timestamp: stream.timestamp,
                                phAssets: photos.reversed(),
                                streams: [stream]
                            )
                            momentDict["\(key)_\(stream.id)"] = newMoment
                        }
                    } else {
                        // Create new moment
                        let newMoment = Moment(
                            place: stream.place,
                            timestamp: stream.timestamp,
                            phAssets: photos.reversed(),
                            streams: [stream]
                        )
                        momentDict[key] = newMoment
                    }
                }

                moments = Array(momentDict.values).sorted {
                    $0.timestamp > $1.timestamp
                }.reversed()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if library.authorized && !moments.isEmpty {
                LibraryView
            } else if !library.authorized && stream != nil {
                PermissionView
            }
        }
        .task(id: id) {
            // Don't prompt if user hasn't interacted yet
            guard requestedAuthorization else { return }

            loadPhotos()
        }
        .fullScreenCover(item: $fullScreenItem, onDismiss: loadPhotos) { item in
            switch item {
            case .moment(let m):
                MomentView(moment: m, namespace: transitionNamespace)
            case .photos(let assets, let streams):
                PhotoView(photos: assets, initialIndex: 0, streams: streams)
                    .navigationTransition(
                        .zoom(
                            sourceID: "MomentGallery",
                            in: transitionNamespace
                        )
                    )
            }
        }
        .onDisappear {
            // Clear Photos library on disappear
            moments = []
        }
    }

    private var LibraryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                if moments.count > 1 {
                    ForEach(moments.reversed(), id: \.id) { mo in
                        MomentGroupTile(
                            moment: mo,
                            namespace: transitionNamespace
                        ) {
                            fullScreenItem = .moment(mo)
                        }
                    }
                } else if let thisMoment = moments.first {
                    ForEach(thisMoment.phAssets, id: \.self) { asset in
                        MomentAssetTile(
                            asset: asset,
                            namespace: transitionNamespace
                        ) {
                            if thisMoment.phAssets.count == 1 {
                                fullScreenItem = .photos(thisMoment.phAssets, thisMoment.streams)
                            } else {
                                fullScreenItem = .moment(thisMoment)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .frame(height: 192)
        }
    }

    private var PermissionView: some View {
        ZStack {
            Rectangle()
                .fill(.quinary)
                .clipShape(.rect(cornerRadius: 14))

            VStack {
                Text("Grant permission to see moments.")
                    .font(.callout)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)

                Button(
                    action: {
                        if requestedAuthorization {
                            // If we've already prompted, go to app-specific settings
                            openURL(
                                URL(
                                    string: UIApplication.openSettingsURLString
                                )!
                            )
                        } else {
                            loadPhotos()
                        }
                    },
                    label: {
                        HStack {
                            Image(
                                systemName: requestedAuthorization
                                    ? "xmark.app" : "photo.stack"
                            )
                            .font(.system(size: 20))
                            Text("Full Photo Library")
                                .font(.callout)
                        }
                    }
                )
                .padding(.top, 4)
            }
            .padding()
        }
        .overlay {
            // MARK: "Ignore" button disabled until Settings view is implemented

            // Show ignore button if user has interacted with permission prompt
            //            HStack(alignment: .top) {
            //                Spacer()
            //                Button(action: {
            //                    ignoredRequest = true
            //                }) {
            //                    Image(systemName: "xmark")
            //                }
            //                .tint(.primary)
            //            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct MomentGroupTile: View {
    let moment: Moment
    let namespace: Namespace.ID
    let onTap: () -> Void
    @State private var size: CGSize = CGSize(width: 128, height: 192)

    var body: some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                Thumbnail(
                    assetLocalId: moment.phAssets.first?.localIdentifier,
                    targetSize: CGSize(width: 384, height: 576)
                )
                .scaledToFill()
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom) {
                    Text(moment.timestamp.day)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            // .clipShape(.rect(cornerRadius: size.width * 0.14))
            .matchedTransitionSource(id: moment.id, in: namespace)
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: {
                size = $0
            }
            .onTapGesture { onTap() }
    }
}

private struct MomentAssetTile: View {
    let asset: PHAsset
    let namespace: Namespace.ID
    let onTap: () -> Void
    @State private var size: CGSize = CGSize(width: 128, height: 192)

    private var nativeAspectRatio: CGFloat {
        let w = CGFloat(asset.pixelWidth)
        let h = CGFloat(asset.pixelHeight)
        guard w > 0, h > 0 else { return 2.0 / 3.0 }
        return w / h
    }

    var body: some View {
        Color.clear
            .aspectRatio(nativeAspectRatio, contentMode: .fit)
            .overlay {
                Thumbnail(
                    assetLocalId: asset.localIdentifier,
                    targetSize: CGSize(width: 576, height: 576)
                )
                .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .matchedTransitionSource(id: "MomentGallery", in: namespace)
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: {
                size = $0
            }
            .onTapGesture { onTap() }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ShazamStream.self,
        configurations: config
    )

    let s = ShazamStream.preview
    return Moments(stream: s)
        .modelContainer(container)
        .environment(LibraryProvider())
}
