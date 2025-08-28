//
//  Photos.swift
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

struct Photos: View {
    @Environment(LibraryProvider.self) private var library
    @Environment(\.openURL) private var openURL

    @AppStorage("hasRequestedPhotosAuthorization") var requestedAuthorization: Bool = false
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

    @State private var moments: [Moment] = []
    @State private var moment: Moment? = nil

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
                    let photos = library.fetchSelectedPhotos(date: stream.timestamp, location: stream.location)
                    guard !photos.isEmpty else { continue }

                    // Create a key based on date (day) and place to group similar moments
                    let calendar = Calendar.current
                    let dayComponent = calendar.startOfDay(for: stream.timestamp)
                    let key = "\(stream.place)_\(dayComponent.timeIntervalSince1970)"

                    if var existingMoment = momentDict[key] {
                        // Add this stream to existing moment if photos are the same
                        let existingPhotoIds = Set(existingMoment.phAssets.map(\.localIdentifier))
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

                moments = Array(momentDict.values).sorted { $0.timestamp > $1.timestamp }.reversed()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if library.authorized && !moments.isEmpty {
                heading
                libraryView
            } else if !library.authorized && stream != nil {
                heading
                permissionView
            }
        }
        .task(id: id) {
            // Don't prompt if user hasn't interacted yet
            guard requestedAuthorization else { return }

            loadPhotos()
        }
        .fullScreenCover(item: $moment) { moment in
            MomentView(moment: moment, namespace: transitionNamespace)
        }
        .onDisappear {
            // Clear Photos library on disappear
            moments = []
        }
    }

    private var heading: some View {
        Text("Moments")
            .font(.subheading)
            .padding(.horizontal)
    }

    private var libraryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                if moments.count > 1 {
                    ForEach(moments.reversed(), id: \.id) { mo in
                        Thumbnail(assetLocalId: mo.phAssets.first!.localIdentifier, targetSize: .init(width: 384, height: 576))
                            .aspectRatio(contentMode: .fill)
                            .aspectRatio(2 / 3, contentMode: .fit)
                            .matchedTransitionSource(id: mo.phAssets.first!.localIdentifier, in: transitionNamespace)
                            .onTapGesture {
                                moment = mo
                            }
                            .overlay(alignment: .bottomLeading) {
                                HStack(alignment: .bottom) {
                                    Text(mo.timestamp.day)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .padding()
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .background(.thinMaterial)
                            }
                            .clipShape(RoundedRectangle(
                                cornerRadius: 8
                            ))
                    }
                } else if let thisMoment = moments.first {
                    ForEach(thisMoment.phAssets, id: \.self) { asset in
                        Thumbnail(assetLocalId: asset.localIdentifier, targetSize: .init(width: 384, height: 576))
                            .aspectRatio(contentMode: .fill)
                            .aspectRatio(2 / 3, contentMode: .fit)
                            .matchedTransitionSource(id: asset.localIdentifier, in: transitionNamespace)
                            .clipShape(RoundedRectangle(
                                cornerRadius: 8
                            ))
                            .onTapGesture {
                                moment = thisMoment
                            }
                    }
                }
            }
            .padding(.horizontal)
            .frame(height: 192)
        }
        .padding(.bottom, 8)
    }

    private var permissionView: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .frame(height: 156)
                .clipShape(.rect(cornerRadius: 14))

            VStack {
                Text("See photos from when you discovered this song.")
                    .multilineTextAlignment(.center)

                Button(action: {
                    if requestedAuthorization {
                        // If we've already prompted, go to app-specific settings
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    } else {
                        loadPhotos()
                    }
                }, label: {
                    HStack {
                        Image(systemName: requestedAuthorization ? "xmark.app" : "photo.stack")
                            .font(.system(size: 20))
                        Text("Full Photo Library")
                    }
                })
                .padding(.top, 8)
            }
            .frame(maxWidth: 244)
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ShazamStream.self, configurations: config)

    let s = ShazamStream.preview
    return Photos(stream: s)
        .modelContainer(container)
        .environment(LibraryProvider())
}
