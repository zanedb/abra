//
//  Annotations.swift
//  Abra
//

import Kingfisher
import MapKit
import SwiftUI

struct ShazamAnnotationView: View {
    var artworkURL: URL

    var body: some View {
        KFImage(artworkURL)
            .resizable()
            .placeholder { ProgressView() }
            .aspectRatio(contentMode: .fit)
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .shadow(radius: 3, x: 2, y: 2)
    }
}

struct ClusterAnnotationView: View {
    var cluster: ShazamClusterAnnotation
//    @State var callout: Bool = false

    var body: some View {
        ZStack {
            KFImage(cluster.artworkURL ?? ShazamStream.preview.artworkURL)
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .blur(radius: 4)

            RoundedRectangle(cornerRadius: 4)
                .fill(Material.regular)
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            Text("\(cluster.count)")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: cluster.count > 1000 ? 11 : 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
//        .onLongPressGesture {
//            callout.toggle()
//        }
//        .overlay {
//            if callout {
//                ClusterCalloutView(action: { print("do it!") }, count: cluster.count)
//                    .padding(.bottom, 8)
//                    .offset(y: -75)
//            }
//        }
    }
}

struct ClusterCalloutView: View {
    let action: () -> Void
    var count: Int

    var body: some View {
        VStack {
            HStack {
                Text("\(count) Shazams selected")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
            }

            Divider()

            Button(action: action) {
                HStack {
                    Text("Group in a playlist")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)

                    Spacer()

                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(12)
        .background(Material.regularMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        .frame(width: 230)
    }
}

#Preview("Annotations Only") {
    @Previewable @State var cluster = ShazamClusterAnnotation(coordinate: .init(latitude: 32.6514, longitude: -161.4333), streamIds: [ShazamStream.preview.id, ShazamStream.preview.id])

    HStack {
        Spacer()

        ShazamAnnotationView(artworkURL: ShazamStream.preview.artworkURL)

        Spacer()

        ClusterAnnotationView(cluster: cluster)

        Spacer()
    }
}

#Preview("Real Thing") {
    @Previewable @State var position = MapCameraPosition.automatic

    MapView(detent: .constant(.height(65)), sheetSelection: .constant(nil), groupSelection: .constant(nil), shazams: [.preview, .preview, .preview])
        .modelContainer(PreviewSampleData.container)
}
