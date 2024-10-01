//
//  Place.swift
//  abra
//
//  Created by Zane on 8/17/24.
//

import Foundation
import SwiftData
import MapKit

@Model final class Place {
    var name: String
    var iconName: String
    var colorName: String
    
    var latitude: Double
    var longitude: Double
    var radius: Double
    var city: String?
    var state: String?
    var country: String?
    var countryCode: String?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String = "", iconName: String = "house", colorName: String = "blue", latitude: Double = 37.3316876, longitude: Double = -122.0327261, radius: Double = 10) {
        self.name = name
        self.iconName = iconName
        self.colorName = colorName
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension Place {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
    static var preview: Place {
        Place(name: "Sioux Falls", iconName: "magnifyingglass", colorName: "blue", latitude: 37.3316876, longitude: -122.0327261, radius: 10)
    }
}
