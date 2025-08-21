//
//  MomentView.swift
//  Abra
//

import Photos
import SwiftUI

struct Moment {
    var place: String
    var timestamp: Date
    var phAssets: [PHAsset] = []
}

struct MomentView: View {
    var moment: Moment
    var namespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .top) {
            // Photos
            ScrollView {
                VStack(spacing: 2) {
                    // First image: full width, 1:1 aspect
                    if let firstAsset = moment.phAssets.first {
                        Thumbnail(assetLocalId: firstAsset.localIdentifier, targetSize: .init(width: 512, height: 512))
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                            .clipped()
                            .navigationTransition(.zoom(sourceID: firstAsset.localIdentifier, in: namespace))
                    }

                    // 3-column grid for remaining images
                    let size = (UIScreen.main.bounds.width / 3) - (2 * 2)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(moment.phAssets.dropFirst(), id: \.self) { asset in
                            Thumbnail(assetLocalId: asset.localIdentifier, targetSize: .init(width: 256, height: 256))
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipped()
                                .navigationTransition(.zoom(sourceID: asset.localIdentifier, in: namespace))
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.all)

            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.75), Color.black.opacity(0.5), Color.black.opacity(0.25), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .frame(height: 180)
            .allowsHitTesting(false)

            // Text
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(moment.place)
                        .font(.title.weight(.medium))
                    Text("\(moment.timestamp.relativeGroupString) · \(moment.phAssets.count) photo\(moment.phAssets.count == 1 ? "" : "s")")
                        .font(.subheadline)

                    Spacer()
                }
                .foregroundStyle(.white)

                Spacer()

                DismissButton(foreground: .white, font: .buttonLarge)
            }
            .padding()
        }
    }
}

#Preview {
    @Previewable var moment: Moment = .init(place: "1015", timestamp: .now, phAssets: [])
    @Previewable @Namespace var namespace

    VStack {}
        .fullScreenCover(isPresented: .constant(true)) {
            MomentView(moment: moment, namespace: namespace)
        }
}
