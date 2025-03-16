//
//  Shazam.swift
//  Abra
//

import Foundation
import ShazamKit
import os

/// Errors that can occur during Shazam operations
enum ShazamError: Error {
    case sessionNotPrepared
    case matchFailed(Error)
    case noMatch
    case libraryError(Error)
}

/// Result type for Shazam matching operations
enum ShazamMatchResult {
    case success(SHMatch)
    case failure(ShazamError)
}

/// Service responsible for Shazam audio recognition functionality
actor ShazamService {
    // MARK: - Properties
    
    private let session: SHManagedSession
    private let logger = Logger(subsystem: "app.zane.abra", category: "ShazamService")
    
    // MARK: - Initialization
    
    init() {
        session = SHManagedSession()
    }
    
    // MARK: - Public Methods
    
    /// Prepares the Shazam session for audio recognition
    func prepare() async {
        do {
            await session.prepare()
            logger.info("Shazam session prepared successfully")
        }
    }
    
    /// Starts a matching session and returns results through the callback
    /// - Parameter resultHandler: Closure called when results are available
    /// - Returns: A task that can be cancelled to stop the matching
    func startMatching(resultHandler: @escaping (ShazamMatchResult) -> Void) -> Task<Void, Never> {
        return Task {
            for await result in session.results {
                if Task.isCancelled {
                    break
                }
                
                switch result {
                case .match(let match):
                    logger.info("Match found: \(match.mediaItems.first?.title ?? "unknown")")
                    resultHandler(.success(match))
                    
                case .noMatch(_):
                    logger.info("No match found")
                    resultHandler(.failure(.noMatch))
                    
                case .error(let error, _):
                    logger.error("Matching error: \(error.localizedDescription)")
                    resultHandler(.failure(.matchFailed(error)))
                }
            }
        }
    }
    
    /// Cancels the current matching session
    func cancelMatching() {
        session.cancel()
        logger.info("Shazam matching cancelled")
    }
    
    /// Adds media items to the Shazam library
    /// - Parameter mediaItems: The media items to add
    func addToLibrary(mediaItems: [SHMediaItem]) async throws {
        do {
            try await SHLibrary.default.addItems(mediaItems)
            logger.info("Added \(mediaItems.count) items to Shazam library")
        } catch {
            logger.error("Failed to add items to Shazam library: \(error.localizedDescription)")
            throw ShazamError.libraryError(error)
        }
    }
    
    /// Removes a media item from the Shazam library
    /// - Parameter itemID: The ID of the item to remove
    func removeFromLibrary(itemID: UUID) async throws {
        let items = await SHLibrary.default.items.filter { $0.id == itemID }
        
        guard let mediaItem = items.first else {
            logger.warning("Item not found in Shazam library: \(itemID)")
            return
        }
        
        do {
            try await SHLibrary.default.removeItems([mediaItem])
            logger.info("Removed item from Shazam library: \(itemID)")
        } catch {
            logger.error("Failed to remove item from library: \(error.localizedDescription)")
            throw ShazamError.libraryError(error)
        }
    }
}
