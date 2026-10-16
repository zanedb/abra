//
//  LocationProvider.swift
//  Abra
//

import CoreLocation
import CoreMotion
import Foundation
import MapKit
import os

struct SearchCompletions: Identifiable {
    let id = UUID()
    let completion: MKLocalSearchCompletion
    var title: String { completion.title }
    var subTitle: String { completion.subtitle }
}

@Observable final class LocationProvider: NSObject, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var currentPlacemark: CLPlacemark?
    @ObservationIgnored var onLocationUpdate: (@MainActor (CLLocation?, CLPlacemark?) -> Void)?
    private var placemarkLocation: CLLocation?
    private var lastObservedDisplacement: CLLocationDistance = 0
    private var backgroundTrackingRequested = false
    private var lastAccuracyAuthorization: CLAccuracyAuthorization
    private let logger = Logger(subsystem: "app.zane.abra", category: "LocationProvider")
    var completions = [SearchCompletions]()
    
    private let locationManager: CLLocationManager
    private let refreshLocationManager: CLLocationManager
    private var refreshRequestedAt: Date?
    private var standardUpdatesRunning = false
    private let completer: MKLocalSearchCompleter
    @ObservationIgnored private var pickerRequests: [UUID: CheckedContinuation<CLLocation, Error>] = [:]
    @ObservationIgnored private var pickerTimeouts: [UUID: Task<Void, Never>] = [:]

    enum PickerError: LocalizedError {
        case permissionDenied, locationUnavailable, placeUnavailable
        var errorDescription: String? {
            switch self {
            case .permissionDenied: "Allow location access for Abra in Settings, or search for a place instead."
            case .locationUnavailable: "Your current location is unavailable. Please try again or search for a place."
            case .placeUnavailable: "That place could not be found. Please select another search result."
            }
        }
    }
    
    override convenience init() {
        self.init(locationManager: CLLocationManager(), refreshLocationManager: CLLocationManager())
    }

    init(locationManager: CLLocationManager, refreshLocationManager: CLLocationManager) {
        self.locationManager = locationManager
        self.refreshLocationManager = refreshLocationManager
        lastAccuracyAuthorization = locationManager.accuracyAuthorization
        completer = MKLocalSearchCompleter()
        super.init()
        
        locationManager.delegate = self
        refreshLocationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        
        completer.delegate = self
    }
    
    // MARK: - Public Methods

    var hasReducedAccuracy: Bool {
        locationManager.accuracyAuthorization == .reducedAccuracy
    }

    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// A one-shot request on an already-running manager is a documented no-op.
    /// Use a separate manager while the primary keeps the background When In Use
    /// session alive; never stop/restart that session just to refresh a stale fix.
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        guard standardUpdatesRunning else {
            locationManager.requestLocation()
            return
        }
        if let refreshRequestedAt, Date().timeIntervalSince(refreshRequestedAt) < 15 { return }
        if refreshRequestedAt != nil { refreshLocationManager.stopUpdatingLocation() }
        refreshLocationManager.desiredAccuracy = hasReducedAccuracy ? kCLLocationAccuracyReduced
            : (backgroundTrackingRequested ? kCLLocationAccuracyHundredMeters : kCLLocationAccuracyBest)
        refreshRequestedAt = .now
        refreshLocationManager.requestLocation()
        logger.info("Requested independent location refresh while continuous updates remain active")
    }

    /// A picker tap requests a fix when the cache is missing or stale. Geocoding
    /// is deliberately independent: a valid coordinate doesn't need a placemark.
    @MainActor
    func locationForPicker() async throws -> CLLocation {
        try Task.checkCancellation()
        guard authorizationStatus != .denied && authorizationStatus != .restricted else {
            throw PickerError.permissionDenied
        }
        let maximumAge: TimeInterval = hasReducedAccuracy ? 300 : 60
        if let currentLocation,
           currentLocation.horizontalAccuracy.isFinite,
           currentLocation.horizontalAccuracy >= 0,
           abs(currentLocation.timestamp.timeIntervalSinceNow) <= maximumAge {
            return currentLocation
        }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                pickerRequests[id] = continuation
                pickerTimeouts[id] = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .seconds(15)) }
                    catch { return }
                    self?.finishPickerRequest(id, result: .failure(PickerError.locationUnavailable))
                }
                if authorizationStatus == .notDetermined { requestPermission() }
                else { requestLocation() }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finishPickerRequest(id, result: .failure(CancellationError()))
            }
        }
    }

    @MainActor
    private func finishPickerRequest(_ id: UUID, result: Result<CLLocation, Error>) {
        pickerTimeouts.removeValue(forKey: id)?.cancel()
        pickerRequests.removeValue(forKey: id)?.resume(with: result)
    }

    @MainActor
    private func finishPickerRequests(result: Result<CLLocation, Error>) {
        for id in Array(pickerRequests.keys) { finishPickerRequest(id, result: result) }
    }

    /// Keep a location session started in the foreground while Continuous
    /// listening runs, so When In Use fixes can still arrive after locking.
    func startBackgroundLocationUpdates() {
        backgroundTrackingRequested = true
        guard authorizationStatus == .authorizedWhenInUse
                || authorizationStatus == .authorizedAlways else { return }
        locationManager.desiredAccuracy = hasReducedAccuracy
            ? kCLLocationAccuracyReduced : kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 150
        locationManager.allowsBackgroundLocationUpdates = true
        refreshLocationManager.allowsBackgroundLocationUpdates = true
        // A pause can end a When In Use location session after the phone locks.
        // Continuous listening needs occasional fresh fixes even when stationary.
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
        standardUpdatesRunning = true
    }

    func stopBackgroundLocationUpdates() {
        backgroundTrackingRequested = false
        standardUpdatesRunning = false
        refreshLocationManager.stopUpdatingLocation()
        refreshRequestedAt = nil
        refreshLocationManager.allowsBackgroundLocationUpdates = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
    }
        
    /// Start continuous location updates
    func startLocationUpdates() {
        standardUpdatesRunning = true
        locationManager.startUpdatingLocation()
    }
        
    /// Stop continuous location updates
    func stopLocationUpdates() {
        guard !backgroundTrackingRequested else { return }
        standardUpdatesRunning = false
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.accuracyAuthorization != lastAccuracyAuthorization
            || (manager.authorizationStatus != .authorizedWhenInUse
                && manager.authorizationStatus != .authorizedAlways) {
            lastAccuracyAuthorization = manager.accuracyAuthorization
            currentLocation = nil
            currentPlacemark = nil
            placemarkLocation = nil
        }
        if backgroundTrackingRequested { startBackgroundLocationUpdates() }
        Task { @MainActor [weak self] in
            guard let self, !pickerRequests.isEmpty else { return }
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                requestLocation()
            } else if authorizationStatus == .denied || authorizationStatus == .restricted {
                finishPickerRequests(result: .failure(PickerError.permissionDenied))
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if manager === refreshLocationManager { refreshRequestedAt = nil }
        guard let location = locations.last,
              location.horizontalAccuracy.isFinite,
              location.horizontalAccuracy >= 0 else { return }
        if let previous = currentLocation {
            guard location.timestamp >= previous.timestamp else { return }
            lastObservedDisplacement = previous.distance(from: location)
        }
        currentLocation = location
        Task { @MainActor [weak self] in
            guard let self else { return }
            let maximumAge: TimeInterval = hasReducedAccuracy ? 300 : 60
            if abs(location.timestamp.timeIntervalSinceNow) <= maximumAge {
                finishPickerRequests(result: .success(location))
            }
            onLocationUpdate?(nil, nil)
        }
        logger.debug("Location fix received; accuracy: \(Int(location.horizontalAccuracy))m")
        if let placemarkLocation, currentPlacemark != nil {
            if placemarkLocation.distance(from: location) < 100 {
                return
            }
            self.currentPlacemark = nil
        }
        fetchPlacemark(for: location)
    }
        
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if manager === refreshLocationManager { refreshRequestedAt = nil }
        logger.error("Location update failed: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let failure: PickerError = authorizationStatus == .denied || authorizationStatus == .restricted
                ? .permissionDenied : .locationUnavailable
            finishPickerRequests(result: .failure(failure))
        }
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        logger.warning("Core Location paused updates during listening: \(self.backgroundTrackingRequested)")
    }

    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        logger.info("Core Location resumed updates")
    }
    
    private func fetchPlacemark(for location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard error == nil, let placemark = placemarks?.first else { return }
            Task { @MainActor [weak self] in
                self?.acceptPlacemark(placemark, for: location)
            }
        }
    }

    @MainActor
    func acceptPlacemark(_ placemark: CLPlacemark, for location: CLLocation) {
        if currentLocation?.distance(from: location) ?? .infinity < 250 {
            currentPlacemark = placemark
            placemarkLocation = location
        }
        // The user may have moved while geocoding. Still deliver the original
        // fix's label to pending songs without relabeling the current position.
        onLocationUpdate?(location, placemark)
    }

    /// Save a recent reduced-accuracy fix as an area, never as a precise point.
    func locationForMatch(at date: Date, activity: CMMotionActivity?) -> CLLocation? {
        guard let currentLocation else {
            logger.warning("Match has no observed location fix")
            return nil
        }
        let age = abs(currentLocation.timestamp.timeIntervalSince(date))
        guard acceptsMatchLocation(currentLocation, at: date, activity: activity,
                                   reducedAccuracy: hasReducedAccuracy) else {
            logger.warning("Match location rejected; age: \(Int(age))s, accuracy: \(currentLocation.horizontalAccuracy)m")
            return nil
        }
        return currentLocation
    }

    func acceptsMatchLocation(
        _ location: CLLocation,
        at date: Date,
        activity: CMMotionActivity?,
        reducedAccuracy: Bool
    ) -> Bool {
        // A neighborhood-level indoor fix is still useful: the saved accuracy
        // produces an uncertainty area and prevents automatic Spot assignment.
        let maximumAccuracy: CLLocationAccuracy = reducedAccuracy ? 50_000 : 2_000
        let maximumAge = reducedAccuracy
            ? broadLocationAgeLimit(activity) : locationAgeLimit(activity)
        return location.horizontalAccuracy.isFinite
            && location.horizontalAccuracy >= 0
            && location.horizontalAccuracy <= maximumAccuracy
            && abs(location.timestamp.timeIntervalSince(date)) <= maximumAge
    }

    func placemark(for location: CLLocation?) -> CLPlacemark? {
        guard let location, let placemarkLocation,
              placemarkLocation.distance(from: location) < 100 else { return nil }
        return currentPlacemark
    }

    /// The activity may show a broader, recently verified place when a song lacks
    /// a sufficiently fresh point. It never labels an old fix as current.
    func activityLocationName(at date: Date, activity: CMMotionActivity?) -> String? {
        guard let currentLocation,
              currentLocation.horizontalAccuracy >= 0,
              currentLocation.horizontalAccuracy <= (hasReducedAccuracy ? 50_000 : 2_000),
              abs(currentLocation.timestamp.timeIntervalSince(date)) <= broadLocationAgeLimit(activity),
              let placemark = placemark(for: currentLocation) else { return nil }

        if !hasReducedAccuracy,
           currentLocation.horizontalAccuracy <= 100,
           abs(currentLocation.timestamp.timeIntervalSince(date)) <= locationAgeLimit(activity),
           let venue = placemark.areasOfInterest?.first, !venue.isEmpty {
            return venue
        }
        if currentLocation.horizontalAccuracy <= 2_000,
           let neighborhood = placemark.subLocality, !neighborhood.isEmpty {
            return neighborhood
        }
        if let city = placemark.locality, !city.isEmpty {
            return currentLocation.horizontalAccuracy > 2_000 ? "Near \(city)" : city
        }
        if let state = placemark.administrativeArea, !state.isEmpty { return state }
        return placemark.country
    }

    func refreshInterval(activity: CMMotionActivity?) -> TimeInterval {
        // Refresh before the accepted fix expires, leaving acquisition headroom.
        if lastObservedDisplacement > 500 { return 45 }
        if lastObservedDisplacement > 150 { return 60 }
        guard let activity, activity.confidence != .low else { return 90 }
        if activity.automotive || activity.cycling { return 60 }
        if activity.stationary { return 120 }
        return 90
    }

    private func locationAgeLimit(_ activity: CMMotionActivity?) -> TimeInterval {
        guard let activity, activity.confidence != .low else { return 180 }
        if activity.automotive || activity.cycling { return 90 }
        if activity.stationary { return 300 }
        return 180
    }

    private func broadLocationAgeLimit(_ activity: CMMotionActivity?) -> TimeInterval {
        guard let activity, activity.confidence != .low else { return 300 }
        if activity.automotive || activity.cycling { return 180 }
        if activity.stationary { return 900 }
        return 300
    }
    
    // MARK: - MKLocalSearchCompleterDelegate

    func update(queryFragment: String) {
        completer.cancel()
        completions = []
        guard !queryFragment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        completer.resultTypes = .pointOfInterest
        if let currentLocation {
            completer.region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                latitudinalMeters: 50_000, longitudinalMeters: 50_000
            )
        }
        completer.queryFragment = queryFragment
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results.map { .init(completion: $0) }
    }

    func search(for selection: SearchCompletions) async throws -> MKMapItem {
        let request = MKLocalSearch.Request(completion: selection.completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        try Task.checkCancellation()
        guard let item = response.mapItems.first(where: {
            $0.name?.localizedCaseInsensitiveCompare(selection.title) == .orderedSame
        }) ?? response.mapItems.first else { throw PickerError.placeUnavailable }
        return item
    }
}
