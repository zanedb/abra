//
//  LibraryProvider.swift
//  Abra
//

import Foundation
import Photos
import UIKit

struct PHFetchResultCollection: RandomAccessCollection, Equatable {
    typealias Element = PHAsset
    typealias Index = Int
    
    var filteredResult: [PHAsset]
    
    var endIndex: Int { filteredResult.count }
    var startIndex: Int { 0 }
    
    subscript(position: Int) -> PHAsset {
        filteredResult[filteredResult.count - position - 1]
    }
}

@Observable final class LibraryProvider {
    typealias PHAssetLocalIdentifier = String
    
    enum QueryError: Error {
        case phAssetNotFound
    }
    
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var authorized: Bool { authorizationStatus == .authorized || authorizationStatus == .limited }
    
    var results = PHFetchResultCollection(filteredResult: [])
    var imageCachingManager = PHCachingImageManager()
    
    func requestAuthorization(callback: (() -> Void)? = nil) {
        UserDefaults.standard.set(true, forKey: "hasRequestedPhotosAuthorization")
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            self?.authorizationStatus = status
            callback?()
        }
    }
    
    func fetchSelectedPhotos(date: Date, location: CLLocation) {
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
        
        let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var filteredAssets: [PHAsset] = []
        let searchRadius: CLLocationDistance = 500 // 0.5km
        
        // Select photos within 0.5km of ShazamStream coord
        allAssets.enumerateObjects { asset, _, _ in
            if let assetLocation = asset.location {
                let distance = assetLocation.distance(from: location)
                if distance <= searchRadius {
                    filteredAssets.append(asset)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.results.filteredResult = filteredAssets
        }
    }
    
    func fetchImage(
        byLocalIdentifier localId: PHAssetLocalIdentifier,
        targetSize: CGSize = PHImageManagerMaximumSize,
        contentMode: PHImageContentMode = .default
    ) async throws -> UIImage? {
        let results = PHAsset.fetchAssets(
            withLocalIdentifiers: [localId],
            options: nil
        )
        
        guard let asset = results.firstObject else {
            throw QueryError.phAssetNotFound
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.imageCachingManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options,
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
}
