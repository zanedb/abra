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
    let title: String
    let subTitle: String
}

struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let location: CLLocationCoordinate2D

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable final class LocationProvider: NSObject, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var currentPlacemark: CLPlacemark?
    private var placemarkLocation: CLLocation?
    private var lastObservedDisplacement: CLLocationDistance = 0
    private var backgroundTrackingRequested = false
    private let logger = Logger(subsystem: "app.zane.abra", category: "LocationProvider")
    var completions = [SearchCompletions]()
    
    private let locationManager: CLLocationManager
    private let completer: MKLocalSearchCompleter
    
    override init() {
        locationManager = CLLocationManager()
        completer = MKLocalSearchCompleter()
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        
        completer.delegate = self
    }
    
    // MARK: - Public Methods

    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Request a one-time location update
    func requestLocation() {
        locationManager.requestLocation()
    }

    /// Keep a location session started in the foreground while Continuous
    /// listening runs, so When In Use fixes can still arrive after locking.
    func startBackgroundLocationUpdates() {
        backgroundTrackingRequested = true
        guard authorizationStatus == .authorizedWhenInUse
                || authorizationStatus == .authorizedAlways else { return }
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 150
        locationManager.allowsBackgroundLocationUpdates = true
        // A pause can end a When In Use location session after the phone locks.
        // Continuous listening needs occasional fresh fixes even when stationary.
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }

    func stopBackgroundLocationUpdates() {
        backgroundTrackingRequested = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
    }
        
    /// Start continuous location updates
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
    }
        
    /// Stop continuous location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if backgroundTrackingRequested { startBackgroundLocationUpdates() }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        if let previous = currentLocation {
            guard location.timestamp >= previous.timestamp else { return }
            lastObservedDisplacement = previous.distance(from: location)
        }
        currentLocation = location
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
        logger.error("Location update failed: \(error.localizedDescription)")
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
            guard let self, error == nil, let placemark = placemarks?.first else { return }
            guard self.currentLocation?.distance(from: location) ?? .infinity < 250 else { return }
            self.currentPlacemark = placemark
            self.placemarkLocation = location
        }
    }

    /// A song receives coordinates only from a recent, reasonably accurate fix.
    func locationForMatch(at date: Date, activity: CMMotionActivity?) -> CLLocation? {
        guard let currentLocation else {
            logger.warning("Match has no observed location fix")
            return nil
        }
        let age = abs(currentLocation.timestamp.timeIntervalSince(date))
        guard currentLocation.horizontalAccuracy >= 0,
              currentLocation.horizontalAccuracy <= 250,
              age <= locationAgeLimit(activity) else {
            logger.warning("Match location rejected; age: \(Int(age))s, accuracy: \(Int(currentLocation.horizontalAccuracy))m")
            return nil
        }
        return currentLocation
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
              currentLocation.horizontalAccuracy <= 2_000,
              abs(currentLocation.timestamp.timeIntervalSince(date)) <= broadLocationAgeLimit(activity),
              let placemark = placemark(for: currentLocation) else { return nil }

        if currentLocation.horizontalAccuracy <= 100,
           abs(currentLocation.timestamp.timeIntervalSince(date)) <= locationAgeLimit(activity),
           let venue = placemark.areasOfInterest?.first, !venue.isEmpty {
            return venue
        }
        if let neighborhood = placemark.subLocality, !neighborhood.isEmpty {
            return neighborhood
        }
        if let city = placemark.locality, !city.isEmpty { return city }
        return nil
    }

    func refreshInterval(activity: CMMotionActivity?) -> TimeInterval {
        if lastObservedDisplacement > 500 { return 60 }
        if lastObservedDisplacement > 150 { return 90 }
        guard let activity, activity.confidence != .low else { return 180 }
        if activity.automotive || activity.cycling { return 90 }
        if activity.stationary { return 300 }
        return 180
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
        completer.resultTypes = .pointOfInterest
        completer.queryFragment = queryFragment
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results.map { .init(title: $0.title, subTitle: $0.subtitle) }
    }
    
    func search(with query: String, coordinate: CLLocationCoordinate2D? = nil) async throws -> [SearchResult] {
        let mapKitRequest = MKLocalSearch.Request()
        mapKitRequest.naturalLanguageQuery = query
        mapKitRequest.resultTypes = .pointOfInterest
        if let coordinate {
            mapKitRequest.region = .init(.init(origin: .init(coordinate), size: .init(width: 1, height: 1)))
        }
        let search = MKLocalSearch(request: mapKitRequest)

        let response = try await search.start()

        return response.mapItems.compactMap { mapItem in
            guard let location = mapItem.placemark.location?.coordinate else { return nil }
            // mapItem.location.coordinate in os26

            return .init(location: location)
        }
    }
}
