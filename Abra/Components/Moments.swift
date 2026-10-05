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

struct MomentSearchInput: Sendable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

enum SpotMomentGrouper {
    static func clusters(
        for inputs: [MomentSearchInput],
        calendar: Calendar = .current,
        radius: CLLocationDistance = LibraryProvider.momentSearchRadius
    ) -> [[Int]] {
        let sortedIndices = inputs.indices.sorted {
            inputs[$0].timestamp < inputs[$1].timestamp
        }
        var clusters: [[Int]] = []

        for inputIndex in sortedIndices {
            let input = inputs[inputIndex]
            let day = calendar.startOfDay(for: input.timestamp)
            let matchingClusterIndex = clusters.firstIndex { cluster in
                guard let firstIndex = cluster.first else { return false }
                let firstDay = calendar.startOfDay(
                    for: inputs[firstIndex].timestamp
                )
                guard firstDay == day else { return false }

                // Keeping every pair within the search radius prevents a chain
                // of nearby songs from merging two genuinely separate places.
                return cluster.allSatisfy { existingIndex in
                    inputs[existingIndex].location.distance(
                        from: input.location
                    ) <= radius
                }
            }

            if let matchingClusterIndex {
                clusters[matchingClusterIndex].append(inputIndex)
            } else {
                clusters.append([inputIndex])
            }
        }

        return clusters
    }

    static func uniqueAssetIdentifiers(
        for clusters: [[Int]],
        identifiersByInput: [[String]]
    ) -> [[String]] {
        var claimedIdentifiers: Set<String> = []

        return clusters.map { cluster in
            var clusterIdentifiers: [String] = []

            for inputIndex in cluster {
                for identifier in identifiersByInput[inputIndex]
                    where claimedIdentifiers.insert(identifier).inserted
                {
                    clusterIdentifiers.append(identifier)
                }
            }

            return clusterIdentifiers
        }
    }
}

private struct LoadedMoment: @unchecked Sendable {
    let inputIndices: [Int]
    let assets: [PHAsset]
}

private enum MomentPhotoLoader {
    static func load(
        inputs: [MomentSearchInput],
        groupAcrossInputs: Bool
    ) -> [LoadedMoment] {
        var materializedAssets: [[PHAsset]] = []
        materializedAssets.reserveCapacity(inputs.count)

        for input in inputs {
            guard !Task.isCancelled else { return [] }
            let assets = LibraryProvider.fetchSelectedPhotos(
                    date: input.timestamp,
                    location: input.location
                )
                .reversed()
            materializedAssets.append(Array(assets))
        }

        let clusters = groupAcrossInputs
            ? SpotMomentGrouper.clusters(for: inputs)
            : inputs.indices.map { [$0] }
        let identifiersByInput = materializedAssets.map {
            $0.map(\.localIdentifier)
        }
        let identifiersByCluster = SpotMomentGrouper.uniqueAssetIdentifiers(
            for: clusters,
            identifiersByInput: identifiersByInput
        )
        let assetsByIdentifier = Dictionary(
            materializedAssets.joined().map {
                ($0.localIdentifier, $0)
            },
            uniquingKeysWith: { first, _ in first }
        )

        return zip(clusters, identifiersByCluster).compactMap {
            cluster, identifiers in
            let assets = identifiers.compactMap { assetsByIdentifier[$0] }
            guard !assets.isEmpty else { return nil }
            return LoadedMoment(inputIndices: cluster, assets: assets)
        }
    }
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

    @MainActor
    private func loadPhotos() async {
        await library.requestAuthorization()
        guard library.authorized else { return }

        let sourceStreams: [ShazamStream]
        let groupAcrossInputs: Bool
        if let stream {
            sourceStreams = [stream]
            groupAcrossInputs = false
        } else if let spot {
            sourceStreams = spot.streams
            groupAcrossInputs = true
        } else {
            return
        }

        let inputs = sourceStreams.map {
            MomentSearchInput(
                timestamp: $0.timestamp,
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }
        // PhotoKit fetches are synchronous, so keep them outside the main actor.
        let photoLoadTask = Task.detached(priority: .userInitiated) {
            MomentPhotoLoader.load(
                inputs: inputs,
                groupAcrossInputs: groupAcrossInputs
            )
        }
        let loadedMoments = await withTaskCancellationHandler {
            await photoLoadTask.value
        } onCancel: {
            photoLoadTask.cancel()
        }
        guard !Task.isCancelled else { return }

        moments = loadedMoments.compactMap { loadedMoment in
            let momentStreams = loadedMoment.inputIndices.map {
                sourceStreams[$0]
            }
            guard let firstStream = momentStreams.first else { return nil }

            return Moment(
                place: firstStream.place,
                timestamp: firstStream.timestamp,
                phAssets: loadedMoment.assets,
                streams: momentStreams
            )
        }
        .sorted { $0.timestamp < $1.timestamp }
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

            await loadPhotos()
        }
        .fullScreenCover(
            item: $fullScreenItem,
            onDismiss: {
                Task { await loadPhotos() }
            }
        ) { item in
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
                            Task { await loadPhotos() }
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
