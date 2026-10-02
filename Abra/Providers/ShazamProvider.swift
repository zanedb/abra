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
    var continuous: Bool = false

    private let session = SHManagedSession()
    private let logger = Logger(subsystem: "app.zane.abra", category: "ShazamProvider")
    @ObservationIgnored private var matchingTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var lastMatchedKey: String?

    weak var sheetProvider: SheetProvider?

    var isMatching: Bool {
        if case .matching = status { return true }
        return false
    }

    init() {
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            // If this runs during onboarding, it’ll ruin the permission request flow
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
        if status == .authorized { return true }
        if status == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
        return false
    }

    /// Starts a Shazam match session
    @MainActor func startMatching() async {
        status = .matching
        // Don't open Searching sheet if continuous mode was pre-enabled (e.g. long press)
        if !continuous {
            sheetProvider?.isSearching = true
        }
        startActivity()

        // In continuous mode, configure audio session for background recording
        if continuous {
            configureAudioSessionForBackground()
        } else {
            // Timeout only makes sense in non-continuous mode
            startTimeoutTask()
        }

        matchingTask = Task { [weak self] in
            guard let self = self else { return }

            // session.results is an AsyncSequence — ShazamKit drives re-listening automatically
            for await result in self.session.results {
                guard !Task.isCancelled else { break }

                self.timeoutTask?.cancel()

                switch result {
                case .match(let match):
                    if let mediaItem = match.mediaItems.first {
                        let matchKey = "\(mediaItem.title ?? "")–\(mediaItem.artist ?? "")"
                        if matchKey != self.lastMatchedKey {
                            self.lastMatchedKey = matchKey
                            self.logger.info("Match found: \(mediaItem.title ?? "unknown")")
                            self.status = .matched(mediaItem)
                            if !self.continuous {
                                self.sheetProvider?.dismissSearching()
                            }
                            Task { [weak self] in
                                guard let self = self else { return }
                                do {
                                    try await self.addToLibrary(mediaItems: match.mediaItems)
                                } catch {
                                    self.logger.error("Failed to add to library: \(error.localizedDescription)")
                                }
                            }
                        } else {
                            self.logger.info("Duplicate match ignored: \(mediaItem.title ?? "unknown")")
                        }
                    }

                case .noMatch:
                    self.logger.info("No match found")
                    if !self.continuous {
                        self.sheetProvider?.dismissSearching()
                        self.status = .error(.noMatch)
                    }

                case .error(let error, _):
                    self.logger.error("Matching error: \(error)")
                    self.sheetProvider?.dismissSearching()
                    self.status = .error(.matchFailed(error))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self.stopMatching() }
                    return
                }

                // In non-continuous mode, stop after the first result
                if !self.continuous { break }
            }

            self.timeoutTask?.cancel()
            guard !Task.isCancelled else { return }
            await MainActor.run { self.stopMatching() }
        }
    }

    @MainActor private func startTimeoutTask() {
        timeoutTask?.cancel()
        let matchStartTime = Date()
        timeoutTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            if case .matching = self.status, Date().timeIntervalSince(matchStartTime) >= 8 {
                await MainActor.run { self.updateActivity(takingTooLong: true) }
            }
        }
    }

    private func configureAudioSessionForBackground() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            logger.info("Audio session configured for background recording")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func restoreAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            logger.info("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    /// Stops the current matching session
    @MainActor func stopMatching() {
        matchingTask?.cancel()
        matchingTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        lastMatchedKey = nil
        continuous = false
        sheetProvider?.dismissSearching()
        session.cancel()
        restoreAudioSession()

        if case .matching = status {
            status = .idle
        }

        endActivity()
        logger.info("Shazam matching stopped")
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
