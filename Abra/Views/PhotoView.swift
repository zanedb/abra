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
    @State private var showingShareSheet = false
    @State private var imageToShare: UIImage?
    
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
                            targetSize: .init(width: 1024, height: 1024)
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
                    
                    Button(action: { shareCurrentPhoto() }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.buttonSmall)
                    }
                }
                .padding()
            }
            .foregroundStyle(.white)
        }
        .background(
            ShareSheetPresenter(
                isPresented: $showingShareSheet,
                activityItems: imageToShare != nil ? [imageToShare!] : []
            )
        )
    }
    
    private func shareCurrentPhoto() {
        let currentAsset = photos[currentIndex]
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
            
        library.imageCachingManager.requestImage(
            for: currentAsset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.imageToShare = image
                self.showingShareSheet = true
            }
        }
    }
}

struct ShareSheetPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && !activityItems.isEmpty {
            let activityVC = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            // For iPad support
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = uiViewController.view
                popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX, y: 0, width: 0, height: 0)
                popover.permittedArrowDirections = .up
            }
            
            uiViewController.present(activityVC, animated: true)
            
            // Reset when dismissed
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }
        }
    }
}
