//
//  Spot.swift
//  Abra
//

import Foundation
import MapKit
import SwiftData

enum SpotType: Hashable, Codable {
    case place
    case vehicle
}

@Model final class Spot {
    var name: String = ""
    var type: SpotType = SpotType.place
    var iconName: String = "mappin.and.ellipse"

    var latitude: Double = 37.721941
    var longitude: Double = -122.4739084
    var city: String?
    var state: String?
    var country: String?
    var countryCode: String?

    @Relationship(deleteRule: .nullify)
    var shazamStreams: [ShazamStream]? = [ShazamStream]()

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(name: String = "", type: SpotType = .place, iconName: String = "house", latitude: Double = 37.3316876, longitude: Double = -122.0327261, shazamStreams: [ShazamStream] = []) {
        self.name = name
        self.type = type
        self.iconName = iconName
        self.latitude = latitude
        self.longitude = longitude
        self.shazamStreams = shazamStreams
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension Spot {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static var preview: Spot {
        Spot(name: "Sioux Falls", type: .place, iconName: "magnifyingglass", latitude: 37.3316876, longitude: -122.0327261, shazamStreams: [ShazamStream.preview])
    }
}
