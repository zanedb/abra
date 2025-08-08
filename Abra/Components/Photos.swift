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

    private var authorized: Bool {
        library.authorizationStatus == .authorized || library.authorizationStatus == .limited
    }

    var stream: ShazamStream

    func requestForAuthorizationIfNecessary() {
        // Make sure photo library access is granted
        // If not, we'll show the permission grant view
        guard library.authorizationStatus != .authorized || library.authorizationStatus != .limited else { return }
        guard requestedAuthorization else { return } // Don't prompt if user hasn't interacted yet
        library.requestAuthorization(date: stream.timestamp,
                                     handleError: { error in
                                         guard error != nil else { return }
                                         print("Photos error occurred")
                                     })
    }

    var body: some View {
        VStack(alignment: .leading) {
            if !authorized {
                if ignoredRequest {
                    EmptyView()
                } else {
                    heading
                    permissionView
                }
            } else {
                if library.results.isEmpty {
                    EmptyView()
                } else {
                    heading
                    libraryView
                }
            }
        }
        .task(id: stream.persistentModelID) {
            requestForAuthorizationIfNecessary()
        }
    }

    private var heading: some View {
        Text("Moments")
            .font(.subheading)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private var libraryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                ForEach(library.results, id: \.self) { asset in
                    Thumbnail(assetLocalId: asset.localIdentifier)
                        .clipShape(RoundedRectangle(
                            cornerRadius: 8
                        ))
                }
            }
            .padding(.horizontal)
            .frame(height: 192)
        }
    }

    private var permissionView: some View {
        ZStack {
            Rectangle()
                .fill(.background)
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
                        library.requestAuthorization(date: stream.timestamp,
                                                     handleError: { error in
                                                         guard error != nil else { return }
                                                         print("Photos error occurred")
                                                     })
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
