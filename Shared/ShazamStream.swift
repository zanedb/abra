//
//  ShazamStream.swift
//  Abra
//
//  The model class of ShazamStream (formerly SStream).
//

import ClusterMap
import Foundation
import MapKit
import SwiftData
import ShazamKit

@Model final class ShazamStream {
    var title: String = ""
    var artist: String = ""
    var isExplicit: Bool = false
    var artworkURL: URL = URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!
    var timestamp: Date = Date.now
    
    var isrc: String?
    var shazamID: String?
    var shazamLibraryID: UUID?
    var appleMusicID: String?
    var appleMusicURL: URL?
    
    var latitude: Double = 37.721941
    var longitude: Double = -122.4739084
    var speed: Double?
    var altitude: Double?
    var thoroughfare: String?
    var city: String?
    var state: String?
    var country: String?
    var countryCode: String?
    
    var spot: Spot?
    
    init(title: String = "", artist: String = "", isExplicit: Bool = false, artworkURL: URL = URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!, latitude: Double = 37.721941, longitude: Double = -122.4739084) {
        self.title = title
        self.artist = artist
        self.isExplicit = isExplicit
        self.timestamp = .now
        self.artworkURL = artworkURL
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(mediaItem: SHMediaItem, location: CLLocation, placemark: CLPlacemark?) {
        self.title = mediaItem.title ?? "Unknown Title"
        self.artist = mediaItem.artist ?? "Unknown Artist"
        self.isExplicit = mediaItem.explicitContent
        self.timestamp = .now
        self.artworkURL = mediaItem.artworkURL ?? URL(string: "https://zane.link/abra-unavailable")!
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        
        // Optional properties
        self.isrc = mediaItem.isrc
        self.shazamID = mediaItem.shazamID
        self.shazamLibraryID = mediaItem.id
        self.appleMusicID = mediaItem.appleMusicID
        self.appleMusicURL = mediaItem.appleMusicURL
        self.altitude = location.altitude
        self.speed = location.speed
        self.thoroughfare = placemark?.thoroughfare
        self.city = placemark?.locality
        self.state = placemark?.administrativeArea
        self.country = placemark?.country
        self.countryCode = placemark?.isoCountryCode
    }
}

extension ShazamStream: CoordinateIdentifiable {
    public var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set(newValue) {
            //
        }
    }
}

extension ShazamStream {
//    public var coordinate: CLLocationCoordinate2D {
//        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//    }
    
    public var cityState: String {
        if city != nil && state != nil {
            "\(city!), \(state!)"
        } else {
            "Unknown"
        }
    }
    
    public var relativeDateTime: String {
        if timestamp.isInLastThirtyDays {
            timestamp.timeSince
        } else {
            timestamp.formatted(.dateTime.day().month())
        }
    }
    
    public var date: String {
        timestamp.formatted(.dateTime.day().month(.wide))
    }
    
    public var time: String {
        timestamp.formatted(.dateTime.hour().minute())
    }
    
    public var timeGroupedString: String {
        timestamp.relativeGroupString
    }
    
    public var placeGroupedString: String {
        thoroughfare ?? "Unknown"
    }
    
    // i.e. "August 11 in San Francisco", "July 4 at 1015"
    public var description: String {
        let date = self.date
        let place = spot?.name ?? city ?? "Unknown"
        
        return "\(date) \(spot?.name != nil ? "at" : "in") \(place)"
    }
    
    // TODO: guess transport modality by speed
    // Need to do more testing
    public var modality: Modality {
        guard let speed = speed else {
            return .still
        }
        
        switch speed {
        case 3 ..< 5:
            return .walking
        case 5...:
            return .driving
        default:
            return .still
        }
    }
    
    static var preview: ShazamStream {
        ShazamStream(title: "The Ills", artist: "Denzel Curry", isExplicit: true,
                     artworkURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!,
                     latitude: 37.721941, longitude: -122.4739084)
    }
}

enum Modality {
    case still
    case walking
    case driving
}
