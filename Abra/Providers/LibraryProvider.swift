//
//  LibraryProvider.swift
//  Abra
//

import AVFoundation
import Foundation
import Photos
import UIKit

@Observable final class LibraryProvider {
    typealias PHAssetLocalIdentifier = String
    
    enum QueryError: Error {
        case phAssetNotFound
    }
    
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var authorized: Bool { authorizationStatus == .authorized || authorizationStatus == .limited }
    
    var imageCachingManager = PHCachingImageManager()
    
    func requestAuthorization(callback: (() -> Void)? = nil) {
        UserDefaults.standard.set(true, forKey: "hasRequestedPhotosAuthorization")
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            self?.authorizationStatus = status
            callback?()
        }
    }
    
    func fetchSelectedPhotos(date: Date, location: CLLocation) -> [PHAsset] {
        imageCachingManager.allowsCachingHighQualityImages = false
        
        let fetchOptions = PHFetchOptions()
        
        // Select photos starting an hour (3600s) before ShazamStream was created
        // and ending an hour (3600s) after
        let startDate = date.addingTimeInterval(-3600)
        let endDate = date.addingTimeInterval(3600)
        fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ && creationDate <= %@", startDate as CVarArg, endDate as CVarArg)
        
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false) // Sort descending
        ]
        
        let imageAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let videoAssets = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        var filteredAssets: [PHAsset] = []
        let searchRadius: CLLocationDistance = 1000

        for fetchResult in [imageAssets, videoAssets] {
            fetchResult.enumerateObjects { asset, _, _ in
                if let assetLocation = asset.location {
                    if assetLocation.distance(from: location) <= searchRadius {
                        filteredAssets.append(asset)
                    }
                }
            }
        }

        return filteredAssets.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
    }
    
    func fetchImage(
        byLocalIdentifier localId: PHAssetLocalIdentifier,
        targetSize: CGSize = PHImageManagerMaximumSize,
        contentMode: PHImageContentMode = .default,
        options: PHImageRequestOptions? = nil
    ) async throws -> UIImage? {
        let results = PHAsset.fetchAssets(
            withLocalIdentifiers: [localId],
            options: nil
        )
        
        guard let asset = results.firstObject else {
            throw QueryError.phAssetNotFound
        }
        
        let defaults = PHImageRequestOptions()
        defaults.deliveryMode = .opportunistic
        defaults.resizeMode = .fast
        defaults.isNetworkAccessAllowed = true
        defaults.isSynchronous = true
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.imageCachingManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options ?? defaults,
                resultHandler: { image, info in
                    if let error = info?[PHImageErrorKey] as? Error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: image)
                }
            )
        }
    }
    
    func fetchAsset(
        byLocalIdentifier localId: PHAssetLocalIdentifier
    ) async throws -> PHAsset {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)

        guard let asset = results.firstObject else {
            throw QueryError.phAssetNotFound
        }

        return asset
    }

    func fetchPlayerItem(
        byLocalIdentifier localId: PHAssetLocalIdentifier
    ) async throws -> AVPlayerItem? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        guard let asset = results.firstObject else { throw QueryError.phAssetNotFound }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: playerItem)
            }
        }
    }

    func fetchVideoURL(
        byLocalIdentifier localId: PHAssetLocalIdentifier
    ) async throws -> URL? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        guard let asset = results.firstObject else { throw QueryError.phAssetNotFound }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (avAsset as? AVURLAsset)?.url)
            }
        }
    }
}
