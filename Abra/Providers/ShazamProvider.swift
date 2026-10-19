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
    case persistenceFailed
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
    private struct PlaybackObservation {
        let date: Date
        let position: TimeInterval?
        let rate: Double
    }
    @ObservationIgnored private var recentlyMatchedSongs: [String: PlaybackObservation] = [:]
    @ObservationIgnored private var possibleReplays: [String: PlaybackObservation] = [:]
    @ObservationIgnored private var activityID: String?
    @ObservationIgnored private var activityStateTask: Task<Void, Never>?
    @ObservationIgnored private var lastActivityState: WidgetAttributes.ContentState?
    @ObservationIgnored private var pendingStart = false
    @ObservationIgnored private var hasPrepared = false
    @ObservationIgnored private var completedMatchTitle: String?
    @ObservationIgnored private var completedMatchArtist: String?
    private struct LocationFix: Equatable {
        let latitude: Double
        let longitude: Double
        let observedAt: Date?
        init(_ stream: ShazamStream) {
            latitude = stream.latitude
            longitude = stream.longitude
            observedAt = stream.locationObservedAt
        }
    }
    private struct PendingLocation {
        let matchedAt: Date
        var expectedFix: LocationFix?
    }
    private struct PendingMatchWrite {
        let stream: ShazamStream
        let context: ModelContext
        let matchedAt: Date
        let sessionID: UUID
        let shazamID: String?
        let playbackPosition: TimeInterval?
        let playbackRate: Double
        let onSaved: (ShazamStream) -> Void
    }
    @ObservationIgnored private var pendingLocations: [PersistentIdentifier: PendingLocation] = [:]
    @ObservationIgnored private var pendingMatchWrites: [UUID: PendingMatchWrite] = [:]
    @ObservationIgnored private var saveRetryTask: Task<Void, Never>?
    @ObservationIgnored private var sessionID = UUID()
    private let saveMatchContext: (ModelContext) throws -> Void
    private let matchFeedback: @MainActor () -> Void

    var pendingMatchSaveCount: Int { pendingMatchWrites.count }
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
        // Recovery belongs to the listening lifecycle, not SwiftUI render callbacks:
        // fixes and placemarks must still enrich records while the screen is locked.
        location.onLocationUpdate = { [weak self] fix, placemark in
            self?.resolvePendingMatchLocations(placemark: placemark, for: fix)
            self?.refreshActivityLocation()
        }
        retryPendingMatches()
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

    func trackLocationRecovery(for stream: ShazamStream, matchedAt: Date) {
        let hasCoordinates = stream.latitude != 0 || stream.longitude != 0
        guard !hasCoordinates || stream.approximateLocationRadius != nil
            || (stream.placemarkName == nil && stream.city == nil && stream.country == nil) else { return }
        pendingLocations[stream.persistentModelID] = PendingLocation(
            matchedAt: matchedAt, expectedFix: hasCoordinates ? LocationFix(stream) : nil
        )
        // A cold launch or stale cache must trigger acquisition now, rather than
        // waiting for the next periodic sample after the recovery window expires.
        if !hasCoordinates { locationProvider?.requestLocation() }
    }

    func resolvePendingMatchLocations(at now: Date = .now,
                                      placemark resolvedPlacemark: CLPlacemark? = nil,
                                      for resolvedLocation: CLLocation? = nil) {
        guard let modelContext, let locationProvider else { return }
        func placemark(for location: CLLocation) -> CLPlacemark? {
            if let resolvedPlacemark, let resolvedLocation,
               resolvedLocation.distance(from: location) < 100 { return resolvedPlacemark }
            return locationProvider.placemark(for: location)
        }
        // Capture a timely fix even if the song's first database write failed.
        // These staged rows aren't editable in the UI yet; their original fix
        // must not be replaced by wherever the user is when saving recovers.
        for entry in pendingMatchWrites.values {
            let stream = entry.stream
            if stream.latitude == 0 && stream.longitude == 0,
               now.timeIntervalSince(entry.matchedAt) < 30,
               let fix = locationProvider.locationForMatch(at: entry.matchedAt, activity: motionProvider?.currentActivity),
               fix.timestamp.timeIntervalSince(entry.matchedAt) <= 30 {
                updateRecoveredLocation(of: stream, to: fix, placemark: placemark(for: fix), matchedAt: entry.matchedAt)
                if !locationProvider.hasReducedAccuracy && fix.horizontalAccuracy <= 50 {
                    stream.spotIt(context: entry.context)
                }
            } else if now.timeIntervalSince(entry.matchedAt) < 300,
                      stream.latitude != 0 || stream.longitude != 0,
                      stream.placemarkName == nil && stream.city == nil && stream.country == nil,
                      let label = placemark(for: stream.location) {
                stream.updatePlacemark(label)
            }
        }
        for (id, var entry) in pendingLocations {
            let descriptor = FetchDescriptor<ShazamStream>(predicate: #Predicate { $0.persistentModelID == id })
            do {
                // Refetch by identity so deleted rows aren't retained/faulted by a
                // delayed callback. Never replace a user's subsequent correction.
                guard let stream = try modelContext.fetch(descriptor).first, !stream.isDeleted else {
                    pendingLocations.removeValue(forKey: id)
                    continue
                }
                if let expected = entry.expectedFix {
                    guard now.timeIntervalSince(entry.matchedAt) < 300,
                          LocationFix(stream) == expected else {
                        pendingLocations.removeValue(forKey: id)
                        continue
                    }
                    // Keep early coarse fixes eligible for a precise acquisition,
                    // even when their city label was already available. Identity
                    // checks above still protect manual edits and deleted rows.
                    if now.timeIntervalSince(entry.matchedAt) < 30,
                       stream.approximateLocationRadius != nil,
                       stream.spot == nil,
                       !locationProvider.hasReducedAccuracy,
                       let fix = locationProvider.locationForMatch(at: entry.matchedAt, activity: motionProvider?.currentActivity),
                       fix.timestamp > (stream.locationObservedAt ?? entry.matchedAt),
                       fix.distance(from: stream.location) <= max(50, stream.approximateLocationRadius ?? 0) + 50,
                       ShazamStream.acceptsEarlyPreciseFix(accuracy: fix.horizontalAccuracy, speed: fix.speed,
                           motionActivity: recoveredMotionActivity(for: stream, location: fix, matchedAt: entry.matchedAt),
                           delay: fix.timestamp.timeIntervalSince(entry.matchedAt)) {
                        try stream.saveLocationEdit { song, context in
                            updateRecoveredLocation(of: song, to: fix, placemark: placemark(for: fix), matchedAt: entry.matchedAt)
                            song.spotIt(context: context)
                        }
                        entry.expectedFix = LocationFix(stream)
                        pendingLocations[id] = entry
                    }
                    if let placemark = placemark(for: stream.location) {
                        try stream.saveLocationEdit { song, _ in song.updatePlacemark(placemark) }
                        if stream.approximateLocationRadius == nil || now.timeIntervalSince(entry.matchedAt) >= 30 {
                            pendingLocations.removeValue(forKey: id)
                        }
                    }
                } else {
                    guard now.timeIntervalSince(entry.matchedAt) < 30,
                          stream.latitude == 0 && stream.longitude == 0,
                          stream.locationObservedAt == nil, stream.spot == nil else {
                        pendingLocations.removeValue(forKey: id)
                        continue
                    }
                    guard let location = locationProvider.locationForMatch(
                        at: entry.matchedAt, activity: motionProvider?.currentActivity
                    ), location.timestamp.timeIntervalSince(entry.matchedAt) <= 30 else { continue }
                    let placemark = placemark(for: location)
                    try stream.saveLocationEdit { song, context in
                        updateRecoveredLocation(of: song, to: location, placemark: placemark, matchedAt: entry.matchedAt)
                        if !locationProvider.hasReducedAccuracy && location.horizontalAccuracy <= 50 {
                            song.spotIt(context: context)
                        }
                    }
                    if placemark != nil && stream.approximateLocationRadius == nil { pendingLocations.removeValue(forKey: id) }
                    else {
                        // A usable fix can precede reverse geocoding. Keep a separate
                        // enrichment stage and only label this exact saved fix.
                        entry.expectedFix = LocationFix(stream)
                        pendingLocations[id] = entry
                    }
                }
            } catch {
                logger.error("Could not enrich match location: \(error.localizedDescription)")
            }
        }
    }

    private func updateRecoveredLocation(of stream: ShazamStream, to location: CLLocation,
                                         placemark: CLPlacemark?, matchedAt: Date) {
        stream.motionActivity = recoveredMotionActivity(for: stream, location: location, matchedAt: matchedAt)
        stream.updateLocation(location, placemark: placemark)
    }

    private func recoveredMotionActivity(for stream: ShazamStream, location: CLLocation, matchedAt: Date) -> String? {
        if let activity = motionProvider?.currentActivity, activity.confidence != .low {
            if activity.automotive { return "automotive" }
            if activity.cycling { return "cycling" }
            if activity.running { return "running" }
            if activity.walking { return "walking" }
        }
        if motionProvider?.confirmsStationary(from: location.timestamp, through: matchedAt) == true {
            return "stationary"
        }
        // A stationary state at recognition alone cannot vouch for a later fix
        // after the user starts moving. Recheck the full interval before using it.
        if stream.motionActivity == "stationary",
           motionProvider?.confirmsStationary(from: location.timestamp, through: matchedAt) != true {
            return "unknown"
        }
        return stream.motionActivity
    }

    /// A failed write retains its staged row, outside the UI context, for retry.
    /// Don't mark it recently saved, notify, or add it to SHLibrary until durable.
    func queueRecognizedMatch(_ stream: ShazamStream, in context: ModelContext,
                              at matchedAt: Date, playbackPosition: TimeInterval? = nil, playbackRate: Double = 1,
                              onSaved: @escaping (ShazamStream) -> Void) {
        let id = stream.matchID ?? UUID()
        stream.matchID = id
        pendingMatchWrites[id] = PendingMatchWrite(
            stream: stream, context: context, matchedAt: matchedAt,
            sessionID: sessionID, shazamID: stream.shazamID,
            playbackPosition: playbackPosition, playbackRate: playbackRate, onSaved: onSaved
        )
        retryPendingMatches()
    }

    func retryPendingMatches() {
        for (id, entry) in pendingMatchWrites {
            do {
                try saveMatchContext(entry.context)
                let rowID = entry.stream.persistentModelID
                let descriptor = FetchDescriptor<ShazamStream>(predicate: #Predicate { $0.persistentModelID == rowID })
                let liveStream = try modelContext?.fetch(descriptor).first ?? entry.stream
                pendingMatchWrites.removeValue(forKey: id)
                if appIsForeground { matchFeedback() }
                // A delayed save from an ended session must not suppress a fresh
                // play in a newly started session.
                if entry.sessionID == sessionID {
                    recordSuccessfulMatch(title: liveStream.title, artist: liveStream.artist, at: entry.matchedAt,
                                          shazamID: entry.shazamID, playbackPosition: entry.playbackPosition,
                                          playbackRate: entry.playbackRate)
                }
                trackLocationRecovery(for: liveStream, matchedAt: entry.matchedAt)
                entry.onSaved(liveStream)
            } catch {
                logger.error("Recognized match retained for save retry: \(error.localizedDescription)")
                status = .error(.persistenceFailed)
            }
        }
        if pendingMatchWrites.isEmpty {
            saveRetryTask?.cancel()
            saveRetryTask = nil
        } else if saveRetryTask == nil {
            saveRetryTask = Task { @MainActor [weak self] in
                var delay: TimeInterval = 2
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(delay)) }
                    catch { return }
                    guard let self else { return }
                    retryPendingMatches()
                    if pendingMatchWrites.isEmpty { return }
                    delay = min(30, delay * 2)
                }
            }
        }
    }

    init(saveMatchContext: @escaping (ModelContext) throws -> Void = { try $0.save() },
         matchFeedback: @escaping @MainActor () -> Void = {
             UINotificationFeedbackGenerator().notificationOccurred(.success)
         }) {
        self.saveMatchContext = saveMatchContext
        self.matchFeedback = matchFeedback
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
        recordLifecycleDiagnostic("provider initialized")
    }

    /// Opens a mic stream to Shazam if possible; decreases time to match
    func prepare() {
        guard !hasPrepared else { return }
        guard configureAudioSessionForBackground() else { return }
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

        sessionID = UUID()
        isListening = true
        matchCount = 0
        recentlyMatchedSongs.removeAll()
        possibleReplays.removeAll()
        completedMatchTitle = nil
        completedMatchArtist = nil
        status = .matching
        recordLifecycleDiagnostic("listening started")
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
                        // Snapshot the SDK's moving prediction once so checking and
                        // saving use the same position and observation time.
                        let recognizedAt = Date()
                        let position = mediaItem.predictedCurrentMatchOffset
                        let rate = 1 + Double(mediaItem.frequencySkew)
                        self.logger.info("Shazam timing id=\(mediaItem.shazamID ?? "unknown", privacy: .public), queryOffset=\(mediaItem.matchOffset), position=\(position), rate=\(rate)")
                        if self.shouldRecordMatch(
                            title: mediaItem.title,
                            artist: mediaItem.artist,
                            at: recognizedAt, shazamID: mediaItem.shazamID,
                            playbackPosition: position, playbackRate: rate
                        ) {
                            self.logger.info("Match found: \(mediaItem.title ?? "unknown")")
                            await self.handleMatch(mediaItem, allItems: match.mediaItems, at: recognizedAt,
                                                   playbackPosition: position, playbackRate: rate)
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
                    await MainActor.run {
                        self.stopMatching(reason: "Shazam error \(nsError.domain) code \(nsError.code)")
                    }
                    return
                }

                // In non-continuous mode, stop after the first result
                if !self.continuous { break }
            }

            self.timeoutTask?.cancel()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.stopMatching(reason: self.continuous ? "Continuous Shazam result stream ended" : "Single match completed")
            }
        }
    }

    private func matchKey(title: String?, artist: String?, shazamID: String? = nil) -> String {
        if let shazamID, !shazamID.isEmpty { return "shazam:\(shazamID)" }
        return "\(title ?? "")–\(artist ?? "")"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func validPosition(_ position: TimeInterval?) -> TimeInterval? {
        guard let position, position.isFinite, position >= 0 else { return nil }
        return position
    }

    /// Compare each song's own playback timeline, even across unrelated results.
    /// A jump alone cannot prove a replay: repeated sections can yield different
    /// offsets. Require a backward reset followed by a second advancing result.
    /// Different songs never wait for this confirmation or a cooldown.
    func shouldRecordMatch(title: String?, artist: String?, at date: Date,
                           shazamID: String? = nil, playbackPosition: TimeInterval? = nil,
                           playbackRate: Double = 1) -> Bool {
        let key = matchKey(title: title, artist: artist, shazamID: shazamID)
        // Histories are cleared when listening stops/starts. Keep valid timelines
        // across long gaps of stray results; evaluate offset-less expiry below.
        // Retain ownership of unsaved matches, without charging saved history.
        guard !pendingMatchWrites.values.contains(where: {
            $0.sessionID == sessionID && matchKey(title: $0.stream.title, artist: $0.stream.artist,
                                                 shazamID: $0.shazamID) == key
        }) else { return false }
        guard let previous = recentlyMatchedSongs[key] else { return true }
        let elapsed = max(0, date.timeIntervalSince(previous.date))
        guard let position = validPosition(playbackPosition), let oldPosition = previous.position else {
            possibleReplays.removeValue(forKey: key)
            return elapsed >= 360
        }
        let expected = oldPosition + elapsed * previous.rate
        // Shazam's query/result latency and DJ tempo changes introduce jitter.
        // Eight seconds plus 8% of elapsed time tolerates that without a fixed
        // ban on replaying the song. Skipping to a different song is unaffected.
        let tolerance = 8 + elapsed * 0.08
        let isSamePlayback = abs(position - expected) <= tolerance
        if isSamePlayback {
            possibleReplays.removeValue(forKey: key)
            // Follow suppressed observations too, so long songs stay suppressed
            // beyond six minutes. A stray result never replaces another timeline.
            recentlyMatchedSongs[key] = PlaybackObservation(
                date: date, position: position, rate: normalizedRate(playbackRate)
            )
            logPlaybackDecision(key: key, position: position, expected: expected, reason: "same playback")
            return false
        }

        // Compare with where the old play would be NOW, rather than requiring a
        // position behind its last observation. A brief capture near zero could
        // otherwise never be replayed after switching away for several minutes.
        // Forward outliers remain suppressed; a reset still needs two advancing
        // observations below the predicted timeline, not a fixed cooldown.
        guard position < expected - tolerance else {
            possibleReplays.removeValue(forKey: key)
            logPlaybackDecision(key: key, position: position, expected: expected, reason: "unconfirmed offset jump")
            return false
        }
        if let candidate = possibleReplays[key] {
            let candidateAge = date.timeIntervalSince(candidate.date)
            let candidateExpected = (candidate.position ?? 0) + candidateAge * candidate.rate
            // Require fresh, independently advancing evidence. Frozen/repeated
            // offsets and alternating section matches must never confirm a reset.
            if (0...30).contains(candidateAge),
               position > (candidate.position ?? 0) + 0.5,
               abs(position - candidateExpected) <= 3 + candidateAge * 0.03 {
                possibleReplays.removeValue(forKey: key)
                logPlaybackDecision(key: key, position: position, expected: expected, reason: "confirmed replay")
                return true
            }
        }
        possibleReplays[key] = PlaybackObservation(
            date: date, position: position, rate: normalizedRate(playbackRate)
        )
        logPlaybackDecision(key: key, position: position, expected: expected, reason: "awaiting replay confirmation")
        return false
    }

    private func logPlaybackDecision(key: String, position: TimeInterval, expected: TimeInterval, reason: String) {
        // Keep decisions at a persisted log level for device diagnosis; no audio
        // or location data is recorded, and notification headlines stay clean.
        logger.notice("Playback \(key, privacy: .public): position=\(position), expected=\(expected), decision=\(reason, privacy: .public)")
    }

    private func normalizedRate(_ rate: Double) -> Double {
        rate.isFinite && (0.5...2).contains(rate) ? rate : 1
    }

    func recordSuccessfulMatch(title: String?, artist: String?, at date: Date,
                               shazamID: String? = nil, playbackPosition: TimeInterval? = nil,
                               playbackRate: Double = 1) {
        let key = matchKey(title: title, artist: artist, shazamID: shazamID)
        // A late retry must not rewind a newer saved play's timeline.
        guard recentlyMatchedSongs[key].map({ $0.date <= date }) ?? true else { return }
        possibleReplays.removeValue(forKey: key)
        recentlyMatchedSongs[key] = PlaybackObservation(
            date: date, position: validPosition(playbackPosition), rate: normalizedRate(playbackRate)
        )
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
            // playAndRecord disables A2DP/AirPlay output unless opted in. Mixing
            // alone keeps music playing but can silently remove its Bluetooth route.
            // Keep stereo output available without opting into the HFP call profile;
            // use the speaker, rather than the receiver, when no accessory is attached.
            let options: AVAudioSession.CategoryOptions = [
                .mixWithOthers, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker
            ]
            if audioSession.category != .playAndRecord || audioSession.mode != .default
                || audioSession.categoryOptions != options {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: options)
            }
            // Configure before SDK preparation, and let SHManagedSession own
            // activation when it starts microphone I/O. Activating separately and
            // reapplying the category can cause extra route/format transitions.
            // Recording normally suppresses haptics, including success feedback.
            if !audioSession.allowHapticsAndSystemSoundsDuringRecording {
                try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
            }
            logger.info("Mixing audio session configured; ShazamKit owns activation")
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
    func stopMatching(reason: String = "User stopped listening") {
        guard isListening else { return }
        recordLifecycleDiagnostic("listening stopped", details: reason)
        isListening = false
        matchingTask?.cancel()
        matchingTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        locationTask?.cancel()
        locationTask = nil
        locationProvider?.stopBackgroundLocationUpdates()
        recentlyMatchedSongs.removeAll()
        possibleReplays.removeAll()
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

    private func handleMatch(_ mediaItem: SHMatchedMediaItem, allItems: [SHMediaItem], at matchedAt: Date,
                             playbackPosition: TimeInterval, playbackRate: Double) async {
        let activity = motionProvider?.currentActivity
        let location = locationProvider?.locationForMatch(at: matchedAt, activity: activity)
        let placemark = locationProvider?.placemark(for: location)
        let motionName: String? = activity.map {
            if $0.automotive { return "automotive" }
            if $0.cycling { return "cycling" }
            if $0.running { return "running" }
            if $0.walking { return "walking" }
            if $0.stationary {
                return motionProvider?.confirmsStationary(from: location?.timestamp ?? matchedAt,
                                                          through: matchedAt) == true ? "stationary" : "unknown"
            }
            return "unknown"
        }

        guard let modelContext else {
            logger.error("Match received before model context was configured")
            return
        }
        let writeContext = ModelContext(modelContext.container)
        writeContext.autosaveEnabled = false
        let stream = ShazamStream(mediaItem: mediaItem, location: location,
                                  placemark: placemark, motionActivity: motionName)
        writeContext.insert(stream)
        if let location, locationProvider?.hasReducedAccuracy == false,
           location.horizontalAccuracy <= 50 {
            stream.spotIt(context: writeContext)
        }
        let recognizedSession = sessionID
        let wasContinuous = continuous
        queueRecognizedMatch(stream, in: writeContext, at: matchedAt,
                             playbackPosition: playbackPosition, playbackRate: playbackRate) { [weak self] stream in
            guard let self else { return }
            let isCurrentSession = recognizedSession == sessionID
            if isCurrentSession {
                matchCount += 1
                updateActivity(takingTooLong: false)
            }
            if !wasContinuous && appIsForeground && isCurrentSession {
                sheetProvider?.dismissSearching()
                sheetProvider?.show(stream)
            } else {
                if !wasContinuous && isCurrentSession && isListening {
                    completedMatchTitle = stream.title
                    completedMatchArtist = stream.artist
                }
                if let matchID = stream.matchID {
                    let title = stream.title
                    let artist = stream.artist
                    Task {
                        await MatchNotificationService.shared.notify(
                            title: title, artist: artist,
                            artworkURL: mediaItem.artworkURL, matchID: matchID
                        )
                    }
                }
            }
            Task {
                do { try await self.addToLibrary(mediaItems: allItems) }
                catch { self.logger.error("Failed to add to library: \(error.localizedDescription)") }
            }
            if !wasContinuous && isCurrentSession { status = .matched(mediaItem) }
            else if isListening && isCurrentSession { status = .matching }
        }
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
        // Set the mode before starting so cold launches and the first Activity
        // use Continuous behavior; an already-running session can opt in too.
        if notification.userInfo?["continuous"] as? Bool == true {
            continuous = true
        }
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
        if isListening { stopMatching(reason: "Live Activity stop control") }
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
        let reason = (notification.userInfo?[AVAudioSessionInterruptionReasonKey] as? NSNumber)?.intValue
        Task { @MainActor [weak self] in
            guard let self, self.isListening else { return }
            self.stopMatching(reason: "Audio interruption: reason=\(reason.map(String.init) ?? "unknown")")
            self.status = .error(.audioSessionFailed)
        }
    }
    
    private func recordLifecycleDiagnostic(_ event: String, details: String = "") {
        // Keep a small local history across launches, including replacement builds.
        // If iOS terminates the process there will be a new initialization without
        // a preceding stop. Never record audio, song titles, or location here.
        let key = "abra.listeningLifecycleDiagnostics"
        var entries = UserDefaults.standard.array(forKey: key) as? [[String: String]] ?? []
        entries.append([
            "time": Date().ISO8601Format(), "event": event, "details": details,
            "sessionID": sessionID.uuidString, "listening": String(isListening),
            "continuous": String(continuous), "matches": String(matchCount),
            "appState": String(UIApplication.shared.applicationState.rawValue)
        ])
        UserDefaults.standard.set(Array(entries.suffix(32)), forKey: key)
        logger.notice("Listening lifecycle: \(event, privacy: .public); \(details, privacy: .public); continuous=\(self.continuous), matches=\(self.matchCount)")
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
            activityStateTask?.cancel()
            activityStateTask = Task { @MainActor [weak self] in
                for await state in activity.activityStateUpdates {
                    guard !Task.isCancelled, let self else { return }
                    recordLifecycleDiagnostic("Live Activity state", details: String(describing: state))
                }
            }
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
        activityStateTask?.cancel()
        activityStateTask = nil
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
