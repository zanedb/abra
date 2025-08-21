//
//  ShazamProvider.swift
//  Abra
//

import ActivityKit
import os
import ShazamKit
import SwiftData
import SwiftUI

enum ShazamError: Error {
    case sessionNotPrepared
    case matchFailed(Error)
    case noMatch
    case libraryError(Error)
}

enum ShazamStatus: Equatable {
    case idle
    case matching
    case matched(SHMatchedMediaItem)
    case error(ShazamError)
    
    static func == (lhs: ShazamStatus, rhs: ShazamStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.matching, .matching):
            return true
        case (.matched(let lhsItem), .matched(let rhsItem)):
            // Since SHMatchedMediaItem doesn't conform to Equatable,
            // we need to determine equality based on its properties
            return lhsItem.id == rhsItem.id
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Shazam API wrapper
@Observable final class ShazamProvider {
    var status: ShazamStatus = .idle

    private let session = SHManagedSession()
    private let logger = Logger(subsystem: "app.zane.abra", category: "ShazamProvider")
    private var matchingTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    
    var isMatching: Bool {
        if case .matching = status {
            return true
        }
        return false
    }
    
    var isMatchingBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.isMatching },
            set: { _ in Task { await self.stopMatching() } }
        )
    }
    
    init() {
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            // If this runs during onboarding, it‘ll ruin the permission request flow
            prepare()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartRecordingIntent),
            name: Notification.Name("StartShazamRecordingIntent"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopRecordingIntent),
            name: Notification.Name("StopShazamRecordingIntent"),
            object: nil
        )
    }
    
    /// Opens a mic stream to Shazam if possible; decreases time to match
    func prepare() {
        Task {
            await session.prepare()
            logger.info("Shazam session prepared successfully")
        }
    }
    
    /// Checks if microphone access is authorized
    /// - Returns: A boolean indicating if permission was granted
    func checkMicrophoneAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
            
        // Return true if already authorized
        if status == .authorized {
            return true
        }
            
        // Request authorization if not determined
        if status == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
            
        return false
    }
    
    /// Starts a Shazam match session
    @MainActor func startMatching() async {
        status = .matching
        startActivity()
        
        // Set a timeout for taking too long
        let matchStartTime = Date()
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(8))
            if case .matching = self.status, Date().timeIntervalSince(matchStartTime) >= 8 {
                await MainActor.run {
                    self.updateActivity(takingTooLong: true)
                }
            }
        }
        
        matchingTask = Task {
            let result = await session.result()
            switch result {
            case .match(let match):
                if let mediaItem = match.mediaItems.first {
                    logger.info("Match found: \(mediaItem.title ?? "unknown")")
                    status = .matched(mediaItem)
                    
                    Task {
                        do {
                            try await addToLibrary(mediaItems: match.mediaItems)
                        } catch {
                            logger.error("Failed to add to library: \(error.localizedDescription)")
                        }
                    }
                }
                
            case .noMatch:
                logger.info("No match found")
                status = .error(.noMatch)
                
            case .error(let error, _):
                logger.error("Matching error: \(error)")
                status = .error(.matchFailed(error))
            }
    
            timeoutTask?.cancel()
            stopMatching()
        }
    }
    
    /// Stops the current matching session
    @MainActor func stopMatching() {
        matchingTask?.cancel()
        matchingTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        
        session.cancel()
        
        // Only reset status if currently matching
        if case .matching = status {
            status = .idle
        }
        
        endActivity()
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
    
    /// Deletes a ShazamStream from the Shazam library
    /// - Parameter stream: The stream to delete
    func removeFromLibrary(stream: ShazamStream) async throws {
        guard let libraryID = stream.shazamLibraryID else {
            logger.warning("Cannot delete stream without a library ID")
            return
        }
        
        let items = await SHLibrary.default.items.filter { $0.id == libraryID }
            
        guard let mediaItem = items.first else {
            logger.warning("Item not found in Shazam library: \(libraryID)")
            return
        }
            
        do {
            try await SHLibrary.default.removeItems([mediaItem])
            logger.info("Removed item from Shazam library: \(libraryID)")
        } catch {
            logger.error("Failed to remove item from library: \(error.localizedDescription)")
            throw ShazamError.libraryError(error)
        }
    }
    
    // MARK: - NotificationCenter Listeners
    
    @objc private func handleStartRecordingIntent(_ notification: Notification) {
        Task {
            await startMatching()
        }
        
        // Power users go on through
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            withAnimation {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
        }
    }
    
    @MainActor @objc private func handleStopRecordingIntent(_ notification: Notification) {
        stopMatching()
    }
    
    // MARK: - Activity Management
        
    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Activities not enabled, skipping")
            return
        }
            
        do {
            let attributes = WidgetAttributes()
            let initialState = WidgetAttributes.ContentState(takingTooLong: false)
                
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
                
            logger.info("Started activity with ID: \(activity.id)")
        } catch {
            logger.error("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func updateActivity(takingTooLong: Bool) {
        Task {
            if let activity = Activity<WidgetAttributes>.activities.first {
                await activity.update(
                    ActivityContent(
                        state: WidgetAttributes.ContentState(takingTooLong: takingTooLong),
                        staleDate: nil
                    )
                )
                logger.debug("Updated activity")
            }
        }
    }
        
    private func endActivity() {
        Task {
            if let activity = Activity<WidgetAttributes>.activities.first {
                let finalState = WidgetAttributes.ContentState(takingTooLong: false)
                    
                await activity.end(
                    .init(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                    
                logger.debug("Ended activity")
            }
        }
    }
}
