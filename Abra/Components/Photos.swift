//
//  Photos.swift
//  Abra
//

import SwiftData
import SwiftUI

struct Photos: View {
    @Environment(LibraryProvider.self) private var library
    @Environment(\.openURL) private var openURL

    @AppStorage("hasRequestedPhotosAuthorization") var requestedAuthorization: Bool = false
    @AppStorage("hasIgnoredPhotosRequest") var ignoredRequest: Bool = false

    @Namespace var transitionNamespace

    var stream: ShazamStream

    @State private var loaded: Bool = false
    @State private var showingMoments = false

    private func loadPhotos() {
        loaded = false // Reset (in case of view replacement)
        // Request authorization, on success load photos
        library.requestAuthorization {
            loaded = true
            if library.authorized {
                library.fetchSelectedPhotos(date: stream.timestamp, location: stream.location)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if loaded {
                if library.authorized && !library.results.isEmpty {
                    heading
                    libraryView
                } else if !library.authorized {
                    heading
                    permissionView
                }
            }
        }
        .task(id: stream.persistentModelID) {
            // Don't prompt if user hasn't interacted yet
            guard requestedAuthorization else { return loaded = true }

            loadPhotos()
        }
        .fullScreenCover(isPresented: $showingMoments) {
            MomentView(moment: .init(place: stream.place, timestamp: stream.timestamp, phAssets: library.results.filteredResult), namespace: transitionNamespace)
        }
        .onDisappear {
            // Clear Photos library on disappear
            library.results.filteredResult = []
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
                ForEach(library.results, id: \.self) { asset in
                    Thumbnail(assetLocalId: asset.localIdentifier, targetSize: .init(width: 384, height: 576))
                        .aspectRatio(contentMode: .fill)
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .matchedTransitionSource(id: asset.localIdentifier, in: transitionNamespace)
                        .clipShape(RoundedRectangle(
                            cornerRadius: 8
                        ))
                }
            }
            .padding(.horizontal)
            .frame(height: 192)
        }
        .onTapGesture {
            showingMoments.toggle()
        }
        .padding(.bottom, 8)
    }

    private var permissionView: some View {
        ZStack {
            Rectangle()
                .fill(.thinMaterial)
                .frame(height: 172)
                .clipShape(RoundedRectangle(
                    cornerRadius: 14
                ))

            VStack {
                Text("We can show photos from this moment if you grant library access.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 1)

                Button(action: {
                    if requestedAuthorization {
                        // If we've already prompted, go to app-specific settings
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    } else {
                        loadPhotos()
                    }
                }, label: {
                    HStack {
                        Image(systemName: requestedAuthorization ? "xmark.app" : "hand.raised.app")
                            .font(.system(size: 24))
                        Text("Full Photo Library")
                    }
                })
                .padding(.top, 8)
            }
            .frame(maxWidth: 256)
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
