//
//  Photos.swift
//  Abra
//

import SwiftData
import SwiftUI

struct Photos: View {
    @Environment(LibraryProvider.self) private var library
    @Environment(\.openURL) private var openURL

    @State private var showError = false

    var stream: ShazamStream

    func requestForAuthorizationIfNecessary() {
        // Make sure photo library access is granted
        // If not, we'll show the permission grant view
        guard library.authorizationStatus != .authorized || library.authorizationStatus != .limited else { return }
        library.requestAuthorization(date: stream.timestamp,
                                     handleError: { error in
                                         guard error != nil else { return }
                                         showError = true
                                     })
    }

    var body: some View {
        VStack {
            if showError {
                permissionView
            } else {
                if library.results.isEmpty {
                    EmptyView()
                } else {
                    libraryView
                }
            }
        }
        .task(id: stream.persistentModelID) {
            requestForAuthorizationIfNecessary()
        }
    }

    var libraryView: some View {
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

    var permissionView: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .frame(height: 172)
                .clipShape(RoundedRectangle(
                    cornerRadius: 8
                ))

            // MARK: this creates an X button that closes the card permanently

            // I'm disabling this for now because it is annoying to reset
            // Also, there's no settings UI yet so no it's irreversible
            // And I want people to use it! Sorry!
//            VStack {
//                HStack {
//                    Spacer()
//                    Button(action: {
//                        library.ignorePhotosRequest()
//                    }) {
//                        Image(systemName: "xmark")
//                    }
//                        .tint(.primary)
//                }
//                Spacer()
//            }
//                .frame(maxHeight: 172)
//                .padding(.top, 24)
//                .padding(.trailing)

            VStack {
                Text("We can show relevant photos if you grant full library access.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 1)

                Button(action: {
                    if showError {
                        // Go to app-specific settings
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    } else {
                        library.requestAuthorization(date: stream.timestamp,
                                                     handleError: { error in
                                                         guard error != nil else { return }
                                                         showError = true
                                                     })
                    }
                }, label: {
                    HStack {
                        Image(systemName: showError ? "xmark.app" : "hand.raised.app")
                            .font(.system(size: 24))
                        Text("Full Photo Library")
                    }
                })
                .padding(.top, 8)
            }
            .padding(.horizontal)
            .frame(maxWidth: 256)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ShazamStream.self, configurations: config)

    let s = ShazamStream.preview
    return Photos(stream: s)
        .padding()
        .modelContainer(container)
        .environment(LibraryProvider())
}
