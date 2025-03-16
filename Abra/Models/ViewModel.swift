//
//  ViewModel.swift
//  Abra
//

import Foundation
import SwiftUI
import SwiftData
import ShazamKit
import CoreData
import MapKit
import ActivityKit
import os

/// Represents the result of a Shazam matching operation
struct MatchResult: Identifiable, Equatable {
    let id = UUID()
    let match: SHMatch?
}

/// Enum representing possible matching errors
enum MatchingError: Error {
    case noLocation
    case shazamError(Error)
    case noMatch
}

/// Main view model for the Abra app
@MainActor final class ViewModel: ObservableObject {
    // MARK: - Properties
    
    var modelContext: ModelContext?
    
    private let location = LocationService.shared
    private let logger = Logger(subsystem: "app.zane.abra", category: "ViewModel")
    private let shazam: ShazamService
    private var matchingTask: Task<Void, Never>?
    private var currentActivity: Activity<WidgetAttributes>?
    
    // MARK: - Published Properties
    
    @Published var selectedDetent: PresentationDetent = .fraction(0.5)
    @Published var selectedSS: ShazamStream?
    @Published var mapSelection: PersistentIdentifier?
    @Published var isMatching = false
    @Published var currentMatchResult: MatchResult?
    @Published var matchingError: MatchingError?
    @Published private(set) var isActivityRunning: Bool = false
    
    var currentMediaItem: SHMatchedMediaItem? {
        currentMatchResult?.match?.mediaItems.first
    }
    
    // MARK: - Initialization
    
    init(shazam: ShazamService = ShazamService()) {
        self.shazam = shazam
        prepare()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopRecordingIntent),
            name: Notification.Name("StopShazamRecordingIntent"),
            object: nil
        )
    }
    
    // MARK: - Private Methods
    
    private func prepare() {
        Task {
            await shazam.prepare()
            location.requestLocation()
        }
    }
    
    private func endSession() {
        isMatching = false
        endActivity()
        currentMatchResult = MatchResult(match: nil)
    }
    
    // MARK: - NotificationCenter Listeners
    
    @objc private func handleStopRecordingIntent(_ notification: Notification) {
        // Handle the intent by stopping recording
        stopRecording()
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
            
            currentActivity = activity
            isActivityRunning = true
            
            logger.info("Started activity with ID: \(activity.id)")
        } catch {
            logger.error("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func updateActivity(takingTooLong: Bool) {
        Task {
            guard let activity = currentActivity else { return }
            
            await activity.update(ActivityContent(state: WidgetAttributes.ContentState(takingTooLong: takingTooLong), staleDate: nil))
            logger.debug("Updated activity with ID: \(activity.id)")
        }
    }
    
    private func endActivity() {
        Task {
            guard let activity = currentActivity else { return }
            
            let finalState = WidgetAttributes.ContentState(takingTooLong: false)
            
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            logger.debug("Ended activity with ID: \(activity.id)")
            
            currentActivity = nil
            isActivityRunning = false
        }
    }
    
    // MARK: - Public Methods
    
    /// Starts a Shazam matching session
    func match() async {
        isMatching = true
        matchingError = nil
        location.requestLocation()
        startActivity()
        
        // Set a timeout for taking too long
        let matchStartTime = Date()
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000) // 8 seconds
            if isMatching && Date().timeIntervalSince(matchStartTime) >= 10 {
                await MainActor.run {
                    updateActivity(takingTooLong: true)
                }
            }
        }
        
        matchingTask = await shazam.startMatching { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let match):
                    self.currentMatchResult = MatchResult(match: match)
                    self.logger.info("Match found: \(self.currentMediaItem?.title ?? "unknown")")
                    
                    do {
                        try await self.createShazamStream(from: self.currentMediaItem)
                        if let mediaItems = self.currentMatchResult?.match?.mediaItems {
                            try await self.shazam.addToLibrary(mediaItems: mediaItems)
                        }
                    } catch MatchingError.noLocation {
                        self.matchingError = .noLocation
                        self.logger.error("No location available for match")
                    } catch {
                        self.matchingError = .shazamError(error)
                        self.logger.error("Error processing match: \(error.localizedDescription)")
                    }
                    
                case .failure(let error):
                    switch error {
                    case .noMatch:
                        self.matchingError = .noMatch
                        self.logger.info("No match found")
                    case .matchFailed(let underlyingError), .libraryError(let underlyingError):
                        self.matchingError = .shazamError(underlyingError)
                        self.logger.error("Shazam error: \(underlyingError.localizedDescription)")
                    case .sessionNotPrepared:
                        self.matchingError = .shazamError(error)
                        self.logger.error("Session not prepared")
                    }
                    
                    self.endSession()
                }
                
                timeoutTask.cancel()
                self.stopRecording()
            }
        }
    }
    
    /// Creates a ShazamStream from a matched media item
    /// - Parameter mediaItem: The matched media item
    /// - Throws: MatchingError.noLocation if location data is unavailable
    func createShazamStream(from mediaItem: SHMatchedMediaItem?) async throws {
        guard let mediaItem = mediaItem else {
            logger.info("No media item available")
            return
        }
        
        guard let latitude = location.lastSeenLocation?.coordinate.latitude,
              let longitude = location.lastSeenLocation?.coordinate.longitude else {
            throw MatchingError.noLocation
        }
        
        let newShazamStream = ShazamStream(
            title: mediaItem.title ?? "Unknown Title",
            artist: mediaItem.artist ?? "Unknown Artist",
            isExplicit: mediaItem.explicitContent,
            artworkURL: mediaItem.artworkURL ?? URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!,
            latitude: latitude,
            longitude: longitude
        )
        
        // Set optional properties
        newShazamStream.isrc = mediaItem.isrc
        newShazamStream.shazamID = mediaItem.shazamID
        newShazamStream.shazamLibraryID = mediaItem.id
        newShazamStream.appleMusicID = mediaItem.appleMusicID
        newShazamStream.appleMusicURL = mediaItem.appleMusicURL
        
        newShazamStream.altitude = location.currentPlacemark?.location?.altitude
        newShazamStream.speed = location.currentPlacemark?.location?.speed
        
        newShazamStream.thoroughfare = location.currentPlacemark?.thoroughfare
        newShazamStream.city = location.currentPlacemark?.locality
        newShazamStream.state = location.currentPlacemark?.administrativeArea
        newShazamStream.country = location.currentPlacemark?.country
        newShazamStream.countryCode = location.currentPlacemark?.isoCountryCode
        
        guard let context = modelContext else {
            logger.error("Model context not available")
            return
        }
        
        context.insert(newShazamStream)
        try context.save()
        
        selectedSS = newShazamStream
        logger.info("Created new ShazamStream: \(newShazamStream.title)")
    }
    
    /// Deletes a ShazamStream from the Shazam library
    /// - Parameter stream: The stream to delete
    func deleteFromShazamLibrary(_ stream: ShazamStream) async throws {
        guard let libraryID = stream.shazamLibraryID else {
            logger.warning("Cannot delete stream without a library ID")
            return
        }
        
        try await shazam.removeFromLibrary(itemID: libraryID)
        logger.info("Deleted item from Shazam library: \(stream.title)")
    }
    
    /// Stops the current recording session
    func stopRecording() {
        matchingTask?.cancel()
        matchingTask = nil
        
        Task {
            await shazam.cancelMatching()
        }
        
        isMatching = false
        endActivity()
    }
}
