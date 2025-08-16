//
//  ShazamStream.swift
//  Abra
//
//  The model class of ShazamStream (formerly SStream).
//

import Foundation
import MapKit
import ShazamKit
import SwiftData

@Model final class ShazamStream {
    var timestamp: Date = Date.now
    
    // SHMediaItem
    var title: String = ""
    var subtitle: String?
    var artist: String = ""
    var artworkURL: URL = URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!
    var videoURL: URL?
    var genres: [String] = []
    var isExplicit: Bool = false
    var creationDate: Date?
    var isrc: String?
    var shazamLibraryID: UUID? // SHMediaItem.id
    var appleMusicURL: URL?
    var appleMusicID: String?
    var webURL: URL?
    var shazamID: String?
    var timeRanges: [Range<TimeInterval>] = []
    var frequencySkewRanges: [Range<Float>] = []
    
    // CLLocation
    var latitude: Double = -1
    var longitude: Double = -1
    var altitude: CLLocationDistance?
    var isProducedByAccessory: Bool?
    var isSimulatedBySoftware: Bool?
    var horizontalAccuracy: CLLocationAccuracy?
    var verticalAccuracy: CLLocationAccuracy?
    var speed: CLLocationSpeed?
    var speedAccuracy: CLLocationSpeedAccuracy?
    var course: CLLocationDirection?
    var courseAccuracy: CLLocationDirectionAccuracy?
    
    // CLPlacemark
    var placemarkName: String? // CLPlacemark.name
    var thoroughfare: String? // Street address
    var subThoroughfare: String? // Street number
    var city: String? // CLPlacemark.locality
    var subLocality: String? // Neighborhood
    var state: String? // CLPlacemark.administrativeArea, state/province
    var subAdministrativeArea: String? // County
    var postalCode: String?
    var countryCode: String? // CLPlacemark.isoCountryCode
    var country: String?
    var inlandWater: String? // Body of water, if above one
    var ocean: String? // If above one
    var areasOfInterest: [String] = []
    var timeZoneIdentifier: String?
    
    // Relations
    var spot: Spot?
    var event: Event?
    
    init(mediaItem: SHMediaItem, location: CLLocation?, placemark: CLPlacemark?) {
        self.timestamp = .now
        
        // SHMediaItem
        self.title = mediaItem.title ?? "Unknown Title"
        self.subtitle = mediaItem.subtitle
        self.artist = mediaItem.artist ?? "Unknown Artist"
        self.artworkURL = mediaItem.artworkURL ?? URL(string: "https://zane.link/abra-unavailable")!
        self.videoURL = mediaItem.videoURL
        self.genres = mediaItem.genres
        self.isExplicit = mediaItem.explicitContent
        self.creationDate = mediaItem.creationDate
        self.isrc = mediaItem.isrc
        self.shazamLibraryID = mediaItem.id
        self.appleMusicURL = mediaItem.appleMusicURL
        self.appleMusicID = mediaItem.appleMusicID
        self.webURL = mediaItem.webURL
        self.shazamID = mediaItem.shazamID
        self.timeRanges = mediaItem.timeRanges
        self.frequencySkewRanges = mediaItem.frequencySkewRanges
        
        // CLLocation
        self.latitude = location?.coordinate.latitude ?? -1
        self.longitude = location?.coordinate.longitude ?? -1
        self.altitude = location?.altitude
        self.isProducedByAccessory = location?.sourceInformation?.isProducedByAccessory
        self.isSimulatedBySoftware = location?.sourceInformation?.isSimulatedBySoftware
        self.horizontalAccuracy = location?.horizontalAccuracy
        self.verticalAccuracy = location?.verticalAccuracy
        self.speed = location?.speed
        self.speedAccuracy = location?.speedAccuracy
        self.course = location?.course
        self.courseAccuracy = location?.courseAccuracy
        
        // CLPlacemark
        self.placemarkName = placemark?.name
        self.thoroughfare = placemark?.thoroughfare
        self.subThoroughfare = placemark?.subThoroughfare
        self.city = placemark?.locality
        self.subLocality = placemark?.subLocality
        self.state = placemark?.administrativeArea
        self.subAdministrativeArea = placemark?.subAdministrativeArea
        self.postalCode = placemark?.postalCode
        self.countryCode = placemark?.isoCountryCode
        self.country = placemark?.country
        self.inlandWater = placemark?.inlandWater
        self.ocean = placemark?.ocean
        self.areasOfInterest = placemark?.areasOfInterest ?? []
        self.timeZoneIdentifier = placemark?.timeZone?.identifier
    }
    
    // .preview initializer
    init(title: String = "", artist: String = "", isExplicit: Bool = false, artworkURL: URL = URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!, latitude: Double = 37.721941, longitude: Double = -122.4739084) {
        self.timestamp = .now
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.genres = []
        self.isExplicit = isExplicit
        self.timeRanges = []
        self.frequencySkewRanges = []
        
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension ShazamStream {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    public var location: CLLocation {
        CLLocation(coordinate: coordinate, altitude: altitude ?? 0.0, horizontalAccuracy: horizontalAccuracy ?? 0.0, verticalAccuracy: verticalAccuracy ?? 0.0, course: course ?? 0.0, courseAccuracy: courseAccuracy ?? 0.0, speed: speed ?? 0.0, speedAccuracy: speedAccuracy ?? 0.0, timestamp: timestamp)
    }
    
    public var cityState: String {
        if let city = city, let state = state {
            "\(city), \(state)"
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
    
    /// Place; i.e. "in San Francisco," "at 1015"
    public var place: String {
        "\(spot?.name != nil ? "at" : "in") \(spot?.name ?? city)"
    }
    
    /// Description; i.e. "August 11 in San Francisco", "July 4 at 1015"
    public var description: String {
        let date = self.date
        
        return "\(date) \(place)"
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
    
    /// Song.link URL
    public var songLink: URL? {
        guard let url = appleMusicURL?.absoluteString else { return nil }
        return URL(string: "https://song.link/\(url)")
    }
    
    public func distance(from other: ShazamStream) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        
        return location1.distance(from: location2)
    }
    
    /// Updates location, using Placemark data as well if possible
    public func updateLocation(_ location: CLLocation, placemark: CLPlacemark? = nil) {
        // CLLocation
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        isProducedByAccessory = location.sourceInformation?.isProducedByAccessory
        isSimulatedBySoftware = location.sourceInformation?.isSimulatedBySoftware
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        speed = location.speed
        speedAccuracy = location.speedAccuracy
        course = location.course
        courseAccuracy = location.courseAccuracy
        
        // CLPlacemark
        placemarkName = placemark?.name
        thoroughfare = placemark?.thoroughfare
        subThoroughfare = placemark?.subThoroughfare
        city = placemark?.locality
        subLocality = placemark?.subLocality
        state = placemark?.administrativeArea
        subAdministrativeArea = placemark?.subAdministrativeArea
        postalCode = placemark?.postalCode
        countryCode = placemark?.isoCountryCode
        country = placemark?.country
        inlandWater = placemark?.inlandWater
        ocean = placemark?.ocean
        areasOfInterest = placemark?.areasOfInterest ?? []
        timeZoneIdentifier = placemark?.timeZone?.identifier
    }
    
    /// Find Spots that are super close by and save to automagically.
    /// Queries for lat/long within three decimal sig figs of precision.
    public func spotIt(context: ModelContext) {
        let precision = 0.001
        let halfPrecision = precision / 2

        let latMin = latitude - halfPrecision
        let latMax = latitude + halfPrecision
        let lonMin = longitude - halfPrecision
        let lonMax = longitude + halfPrecision
        
        let predicate = #Predicate<Spot> {
            $0.latitude >= latMin && $0.latitude < latMax &&
                $0.longitude >= lonMin && $0.longitude < lonMax
        }
            
        let fetchDescriptor = FetchDescriptor<Spot>(predicate: predicate)
        
        do {
            let spots = try context.fetch(fetchDescriptor)
            for item in spots {
                if item.type != .place { continue } // Only SpotType.place groups by location
                spot = item
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static var preview: ShazamStream {
        ShazamStream(
            title: "The Ills",
            artist: "Denzel Curry",
            isExplicit: true,
            artworkURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!,
            latitude: 37.721941,
            longitude: -122.4739084
        )
    }
}

enum Modality {
    case still
    case walking
    case driving
}
