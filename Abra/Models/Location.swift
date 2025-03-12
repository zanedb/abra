//
//  Location.swift
//  Abra
//
//  Originally based on: https://www.andyibanez.com/posts/using-corelocation-with-swiftui/
//

import Foundation
import CoreLocation
import MapKit

class Location: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = Location() // not sure this is the best way to handle this
    
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastSeenLocation: CLLocation?
    @Published var currentPlacemark: CLPlacemark?
    
    private let locationManager: CLLocationManager
    
    override init() {
        locationManager = CLLocationManager()
        authorizationStatus = locationManager.authorizationStatus
        
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        //locationManager.startUpdatingLocation()
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastSeenLocation = locations.first
        fetchCountryAndCity(for: lastSeenLocation)
    }
    
    func fetchCountryAndCity(for location: CLLocation?) {
        guard let location = location else { return }
        
        // TODO: put some throttling code in here
        // see: https://developer.apple.com/documentation/corelocation/converting_a_user_s_location_to_a_descriptive_placemark#3172197
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            self.currentPlacemark = placemarks?.first
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // todo handle this
        print("locationManager ERROR! Perhaps permission not granted? Are you in the Simulator?")
        print(error.localizedDescription)
    }
}
