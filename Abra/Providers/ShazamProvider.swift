//
//  ShazamProvider.swift
//  Abra
//

import ActivityKit
import CoreMotion
import os
import ShazamKit
import SwiftData
import SwiftUI

enum ShazamError: Error {
    case microphonePermissionDenied
    case audioSessionFailed
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
@MainActor @Observable final class ShazamProvider {
    static let shared = ShazamProvider()
    var status: ShazamStatus = .idle
    var continuous: Bool = false {
        didSet {
            guard isListening, continuous != oldValue else { return }
            if continuous { startLocationSampling() }
            else {
                locationTask?.cancel()
                locationProvider?.stopBackgroundLocationUpdates()
                startTimeoutTask()
            }
            updateActivity(takingTooLong: false)
        }
    }
    private(set) var isListening = false
    private(set) var matchCount = 0
    var appIsForeground: Bool { UIApplication.shared.applicationState == .active }

    private let session = SHManagedSession()
    private let logger = Logger(subsystem: "app.zane.abra", category: "ShazamProvider")
    @ObservationIgnored private var matchingTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var locationTask: Task<Void, Never>?
    @ObservationIgnored private var recentlyMatchedSongs: [String: Date] = [:]
    @ObservationIgnored private var activityID: String?
    @ObservationIgnored private var lastActivityState: WidgetAttributes.ContentState?
    @ObservationIgnored private var pendingStart = false
    @ObservationIgnored private var hasPrepared = false
    @ObservationIgnored private var completedMatchTitle: String?
    @ObservationIgnored private var completedMatchArtist: String?
    @ObservationIgnored private var pendingLocationMatches: [(stream: ShazamStream, matchedAt: Date)] = []
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private weak var locationProvider: LocationProvider?
    @ObservationIgnored private weak var motionProvider: MotionProvider?

    weak var sheetProvider: SheetProvider?

    var isMatching: Bool {
        isListening
    }

    func configure(
        modelContext: ModelContext,
        location: LocationProvider,
        motion: MotionProvider,
        sheet: SheetProvider
    ) {
        self.modelContext = modelContext
        locationProvider = location
        motionProvider = motion
        sheetProvider = sheet
        if appIsForeground && UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            prepare()
        }
        if pendingStart {
            pendingStart = false
            Task { await startMatching() }
        }
        _ = MatchNotificationService.shared
        for activity in Activity<WidgetAttributes>.activities where activity.activityState == .active {
            if isListening { activityID = activity.id }
            else {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }

    func refreshActivityLocation() {
        if isListening && continuous { updateActivity(takingTooLong: false) }
    }

    func resolvePendingMatchLocations() {
        guard let modelContext, let locationProvider else { return }
        let now = Date()
        pendingLocationMatches.removeAll { entry in
            guard now.timeIntervalSince(entry.matchedAt) < 30 else { return true }
            guard let location = locationProvider.locationForMatch(
                at: entry.matchedAt,
                activity: motionProvider?.currentActivity
            ), location.timestamp.timeIntervalSince(entry.matchedAt) <= 10 else { return false }
            entry.stream.updateLocation(location, placemark: locationProvider.placemark(for: location))
            if !locationProvider.hasReducedAccuracy && location.horizontalAccuracy <= 50 {
                entry.stream.spotIt(context: modelContext)
            }
            do { try modelContext.save() }
            catch { logger.error("Could not save delayed match location: \(error.localizedDescription)") }
            return true
        }
    }

    init() {
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    /// Opens a mic stream to Shazam if possible; decreases time to match
    func prepare() {
        guard !hasPrepared else { return }
        hasPrepared = true
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
    func startMatching() async {
        guard !isListening else { return }
        if await MatchNotificationService.shared.needsPermissionRequest() {
            await MatchNotificationService.shared.requestPermission()
        }
        await beginMatching()
    }

    private func beginMatching() async {
        guard !isListening else { return }
        guard modelContext != nil else {
            pendingStart = true
            return
        }
        guard await checkMicrophoneAuthorization() else {
            status = .error(.microphonePermissionDenied)
            return
        }
        guard configureAudioSessionForBackground() else {
            status = .error(.audioSessionFailed)
            return
        }

        isListening = true
        matchCount = 0
        recentlyMatchedSongs.removeAll()
        completedMatchTitle = nil
        completedMatchArtist = nil
        status = .matching
        // Don't open Searching sheet if continuous mode was pre-enabled (e.g. long press)
        if !continuous {
            sheetProvider?.isSearching = true
        }
        startActivity()
        locationProvider?.requestLocation()

        if continuous {
            startLocationSampling()
        } else {
            // Timeout only makes sense in non-continuous mode
            startTimeoutTask()
        }

        matchingTask = Task { [weak self] in
            guard let self = self else { return }
            var consecutiveInvalidSignatures = 0

            // session.results is an AsyncSequence — ShazamKit drives re-listening automatically
            for await result in self.session.results {
                guard !Task.isCancelled else { break }

                self.timeoutTask?.cancel()

                switch result {
                case .match(let match):
                    consecutiveInvalidSignatures = 0
                    if let mediaItem = match.mediaItems.first {
                        if self.shouldRecordMatch(
                            title: mediaItem.title,
                            artist: mediaItem.artist,
                            at: .now
                        ) {
                            self.logger.info("Match found: \(mediaItem.title ?? "unknown")")
                            await self.handleMatch(mediaItem, allItems: match.mediaItems)
                        } else {
                            self.logger.info("Recently matched song ignored: \(mediaItem.title ?? "unknown")")
                        }
                    }

                case .noMatch:
                    consecutiveInvalidSignatures = 0
                    self.logger.info("No match found")
                    if !self.continuous {
                        self.sheetProvider?.dismissSearching()
                        self.status = .error(.noMatch)
                    }

                case .error(let error, _):
                    let nsError = error as NSError
                    self.logger.error("Matching error: \(error.localizedDescription, privacy: .public), domain: \(nsError.domain, privacy: .public), code: \(nsError.code)")
                    if self.continuous,
                       nsError.domain == SHErrorDomain,
                       nsError.code == SHError.Code.signatureDurationInvalid.rawValue {
                        consecutiveInvalidSignatures += 1
                        if consecutiveInvalidSignatures < 3 {
                            self.logger.warning("Skipping invalid Shazam signature; listening continues")
                            continue
                        }
                    }
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

    /// A stray intervening result must not make the song already playing new again.
    func shouldRecordMatch(title: String?, artist: String?, at date: Date) -> Bool {
        let key = "\(title ?? "")–\(artist ?? "")"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        recentlyMatchedSongs = recentlyMatchedSongs.filter {
            date.timeIntervalSince($0.value) < 360
        }
        guard recentlyMatchedSongs[key] == nil else { return false }
        recentlyMatchedSongs[key] = date
        return true
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

    private func configureAudioSessionForBackground() -> Bool {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            logger.info("Audio session configured for background recording")
            return true
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
            return false
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
    func stopMatching() {
        guard isListening else { return }
        isListening = false
        matchingTask?.cancel()
        matchingTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        locationTask?.cancel()
        locationTask = nil
        locationProvider?.stopBackgroundLocationUpdates()
        recentlyMatchedSongs.removeAll()
        continuous = false
        sheetProvider?.dismissSearching()
        session.cancel()
        restoreAudioSession()

        if case .matching = status {
            status = .idle
        }

        endActivity()
        completedMatchTitle = nil
        completedMatchArtist = nil
        logger.info("Shazam matching stopped")
    }

    private func handleMatch(_ mediaItem: SHMatchedMediaItem, allItems: [SHMediaItem]) async {
        let matchedAt = Date()
        let activity = motionProvider?.currentActivity
        let location = locationProvider?.locationForMatch(at: matchedAt, activity: activity)
        let placemark = locationProvider?.placemark(for: location)
        let motionName: String? = activity.map {
            if $0.automotive { return "automotive" }
            if $0.cycling { return "cycling" }
            if $0.running { return "running" }
            if $0.walking { return "walking" }
            if $0.stationary { return "stationary" }
            return "unknown"
        }

        if let modelContext {
            let stream = ShazamStream(
                mediaItem: mediaItem,
                location: location,
                placemark: placemark,
                motionActivity: motionName
            )
            modelContext.insert(stream)
            if let location, locationProvider?.hasReducedAccuracy == false,
               location.horizontalAccuracy <= 50 {
                stream.spotIt(context: modelContext)
            }
            do {
                try modelContext.save()
                if location == nil {
                    pendingLocationMatches.removeAll {
                        matchedAt.timeIntervalSince($0.matchedAt) >= 30
                    }
                    pendingLocationMatches.append((stream, matchedAt))
                }
                matchCount += 1
                updateActivity(takingTooLong: false)
                if !continuous && appIsForeground {
                    sheetProvider?.dismissSearching()
                    sheetProvider?.show(stream)
                } else {
                    if !continuous {
                        completedMatchTitle = stream.title
                        completedMatchArtist = stream.artist
                    }
                    let confidence: Int? = if #available(iOS 18.4, *) {
                        Int((mediaItem.confidence * 100).rounded())
                    } else {
                        nil
                    }
                    let title = stream.title
                    let artist = stream.artist
                    let artworkURL = mediaItem.artworkURL
                    let matchID = stream.matchID ?? mediaItem.id
                    Task {
                        await MatchNotificationService.shared.notify(
                            title: title,
                            artist: artist,
                            confidence: confidence,
                            artworkURL: artworkURL,
                            matchID: matchID
                        )
                    }
                }
            } catch {
                modelContext.delete(stream)
                logger.error("Could not save match: \(error.localizedDescription)")
            }
        } else {
            logger.error("Match received before model context was configured")
        }

        Task {
            do {
                try await addToLibrary(mediaItems: allItems)
            } catch {
                logger.error("Failed to add to library: \(error.localizedDescription)")
            }
        }
        if !continuous { status = .matched(mediaItem) }
    }

    private func startLocationSampling() {
        locationTask?.cancel()
        locationProvider?.startBackgroundLocationUpdates()
        locationProvider?.requestLocation()
        locationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isListening && self.continuous {
                let interval = self.locationProvider?.refreshInterval(
                    activity: self.motionProvider?.currentActivity
                ) ?? 180
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                self.locationProvider?.requestLocation()
                self.updateActivity(takingTooLong: false)
            }
        }
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
        
        let items = SHLibrary.default.items.filter { $0.id == libraryID }
            
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
        if isListening { stopMatching() }
        else if let id = notification.userInfo?["activityID"] as? String {
            Task {
                if let activity = Activity<WidgetAttributes>.activities.first(where: { $0.id == id }) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }

    @objc nonisolated private func handleAudioInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: rawType) == .began else { return }
        Task { @MainActor [weak self] in
            guard let self, self.isListening else { return }
            self.logger.warning("Audio session interrupted; ending recognition")
            self.stopMatching()
            self.status = .error(.audioSessionFailed)
        }
    }
    
    // MARK: - Activity Management
        
    private func startActivity() {
        guard activityID == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Activities not enabled, skipping")
            return
        }
            
        do {
            let attributes = WidgetAttributes()
            let initialState = activityState(takingTooLong: false)
                
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
                
            activityID = activity.id
            lastActivityState = initialState
            logger.info("Started activity with ID: \(activity.id)")
        } catch {
            logger.error("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func updateActivity(takingTooLong: Bool) {
        guard let activityID else { return }
        let state = activityState(takingTooLong: takingTooLong)
        guard state != lastActivityState else { return }
        lastActivityState = state
        Task {
            if let activity = Activity<WidgetAttributes>.activities.first(where: { $0.id == activityID }) {
                await activity.update(
                    ActivityContent(
                        state: state,
                        staleDate: nil
                    )
                )
                logger.debug("Updated activity")
            }
        }
    }
        
    private func endActivity() {
        guard let activityID else { return }
        self.activityID = nil
        lastActivityState = nil
        let finalState = activityState(takingTooLong: false)
        let dismissalPolicy: ActivityUIDismissalPolicy = completedMatchTitle == nil
            ? .immediate : .after(Date().addingTimeInterval(120))
        Task {
            if let activity = Activity<WidgetAttributes>.activities.first(where: { $0.id == activityID }) {
                await activity.end(
                    .init(state: finalState, staleDate: nil),
                    dismissalPolicy: dismissalPolicy
                )
                    
                logger.debug("Ended activity")
            }
        }
    }

    private func activityState(takingTooLong: Bool) -> WidgetAttributes.ContentState {
        WidgetAttributes.ContentState(
            takingTooLong: takingTooLong,
            continuous: continuous,
            matchCount: matchCount,
            locationName: continuous
                ? locationProvider?.activityLocationName(
                    at: .now,
                    activity: motionProvider?.currentActivity
                ) : nil,
            matchedTitle: isListening ? nil : completedMatchTitle,
            matchedArtist: isListening ? nil : completedMatchArtist
        )
    }
}
