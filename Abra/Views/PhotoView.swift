//
//  PhotoView.swift
//  Abra
//

import Photos
import SwiftUI

struct PhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryProvider.self) private var library
    
    let photos: [PHAsset]
    
    @State private var currentIndex: Int
    @State private var imageToShare: Image?
    
    init(photos: [PHAsset], initialIndex: Int) {
        self.photos = photos
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    GeometryReader { geometry in
                        Thumbnail(
                            assetLocalId: photos[index].localIdentifier,
                            targetSize: .init(width: 1024, height: 1024),
                            callback: { image in
                                imageToShare = Image(uiImage: image)
                            }
                        )
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Text("\(currentIndex + 1) of \(photos.count)")
                        .fontWeight(.medium)
                    Spacer()
                }
                .overlay(alignment: .leading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.buttonSmall)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                
                Spacer()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(photos[currentIndex].creationDate ?? .distantPast, style: .time)
                            .font(.headline)
                        Text(photos[currentIndex].creationDate ?? .distantPast, style: .date)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    if let imageToShare {
                        ShareLink(item: imageToShare,
                                  preview: SharePreview("", image: imageToShare),
                                  label: {
                                      Image(systemName: "square.and.arrow.up")
                                          .font(.buttonSmall)
                                  })
                    }
                }
                .padding()
            }
            .foregroundStyle(.white)
        }
    }
}
