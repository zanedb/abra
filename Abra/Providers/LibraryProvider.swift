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
    
    var fetchResult: PHFetchResult<PHAsset>
    
    var endIndex: Int { fetchResult.count }
    var startIndex: Int { 0 }
    
    subscript(position: Int) -> PHAsset {
        fetchResult.object(at:  fetchResult.count - position - 1)
    }
}

@Observable final class LibraryProvider {
    var hasIgnoredPhotosRequest: Bool = false
    
    typealias PHAssetLocalIdentifier = String
    
    enum AuthorizationError: Error {
        case restrictedAccess
    }
    
    enum QueryError: Error {
        case phAssetNotFound
    }
    
    init() {
        hasIgnoredPhotosRequest = UserDefaults.standard.bool(forKey: "hasIgnoredPhotosRequest")
    }
    
    // Whether the user has granted us library access
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    // Collection that stores photo asset IDs
    var results = PHFetchResultCollection(fetchResult: .init())
    
    // The manager that will fetch and cache photos for us
    var imageCachingManager = PHCachingImageManager()
    
    func requestAuthorization(date: Date, handleError: ((AuthorizationError?) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            self?.authorizationStatus = status
            
            switch status {
            // If access granted, fetch photo asset IDs
            case .authorized, .limited:
                self?.fetchSelectedPhotos(date: date)
            // If denied, show error
            case .denied, .notDetermined, .restricted:
                handleError?(.restrictedAccess)
            @unknown default:
                break
            }
        }
    }
    
    private func fetchSelectedPhotos(date: Date) {
        imageCachingManager.allowsCachingHighQualityImages = false
        
        let fetchOptions = PHFetchOptions()
        
        // Select photos starting an hour (3600s) before ShazamStream was created
        // and ending an hour (3600s) after
        let startDate = date.addingTimeInterval(-3600)
        let endDate = date.addingTimeInterval(3600)
        fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ && creationDate <= %@", startDate as CVarArg, endDate as CVarArg)
        
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false) // sort descending
        ]
        
        DispatchQueue.main.async {
            self.results.fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
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
        
        return try await withCheckedThrowingContinuation{ [weak self] continuation in
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
    
    func ignorePhotosRequest() {
        UserDefaults.standard.set(true, forKey: "hasIgnoredPhotosRequest")
        hasIgnoredPhotosRequest = true
    }
}
