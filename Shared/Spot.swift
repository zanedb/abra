//
//  Spot.swift
//  Abra
//

import Foundation
import MapKit
import SwiftData

@Model final class Spot {
    var name: String = ""
    var symbol: String = "mappin.and.ellipse"
    @Attribute(.transformable(by: UIColorValueTransformer.self)) var color: UIColor = UIColor.systemIndigo

    var latitude: Double = 37.721941
    var longitude: Double = -122.4739084
    var city: String?
    var state: String?
    var country: String?
    var countryCode: String?
    
    var mapItemIdentifier: String?
    var pointOfInterestCategory: String?
    var phoneNumber: String?
    var url: URL?
    var timeZoneIdentifier: String?

    @Relationship(deleteRule: .nullify, inverse: \ShazamStream.spot)
    var shazamStreams: [ShazamStream]? = [ShazamStream]()

    @Relationship(deleteRule: .cascade, inverse: \Event.spot)
    var events: [Event]? = [Event]()

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(name: String = "", symbol: String = "house", color: UIColor = .systemIndigo, latitude: Double = 37.3316876, longitude: Double = -122.0327261, shazamStreams: [ShazamStream] = []) {
        self.name = name
        self.symbol = symbol
        self.color = color
        self.latitude = latitude
        self.longitude = longitude
        self.shazamStreams = shazamStreams
        self.createdAt = .now
        self.updatedAt = .now
    }

    init(locationFrom: ShazamStream, streams: [ShazamStream]) {
        self.name = ""
        self.symbol = ""
        self.color = .systemGray3 // TODO: random selection
        self.shazamStreams = streams
        self.createdAt = .now
        self.updatedAt = .now

        self.latitude = locationFrom.latitude
        self.longitude = locationFrom.longitude
        self.city = locationFrom.city
        self.state = locationFrom.state
        self.country = locationFrom.country
        self.countryCode = locationFrom.countryCode
    }
    
    init(from featureAnnotation: MKMapFeatureAnnotation) {
        self.name = featureAnnotation.title ?? ""
        self.symbol = ""
        self.color = featureAnnotation.iconStyle?.backgroundColor ?? .systemGray3
        self.shazamStreams = []
        self.createdAt = .now
        self.updatedAt = .now

        self.latitude = featureAnnotation.coordinate.latitude
        self.longitude = featureAnnotation.coordinate.longitude
    }
}

extension Spot {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// i.e. "San Francisco, CA"
    public var description: String {
        if city != nil && state != nil {
            "\(city!), \(state!)"
        } else {
            "Unknown"
        }
    }

    /// Plays the Spot's contents; optionally shuffle
    /// In the future, will play a station based on Spot's Shazams
    public func play(_ music: MusicProvider, shuffle: Bool = false) {
        var trackIds = shazamStreams?.compactMap(\.appleMusicID)

        if shuffle {
            trackIds?.shuffle()
        }

        Task {
            await music.play(ids: trackIds ?? [])
        }
    }

    /// Save ShazamStreams within a close nearby area to the Spot
    /// Queries for lat/long within three decimal sig figs of precision
    public func appendNearbyShazamStreams(_ context: ModelContext) {
        let precision = 0.001
        let halfPrecision = precision / 2

        let latMin = latitude - halfPrecision
        let latMax = latitude + halfPrecision
        let lonMin = longitude - halfPrecision
        let lonMax = longitude + halfPrecision

        let predicate = #Predicate<ShazamStream> {
            $0.latitude >= latMin && $0.latitude < latMax &&
                $0.longitude >= lonMin && $0.longitude < lonMax && $0.spot == nil
        }

        let fetchDescriptor = FetchDescriptor<ShazamStream>(predicate: predicate)

        do {
            let streams = try context.fetch(fetchDescriptor)
            shazamStreams?.append(contentsOf: streams)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func affiliateMapItem(from mapFeatureAnnotation: MKMapFeatureAnnotation) async {
        let mapItem = try? await MKMapItemRequest(mapFeatureAnnotation: mapFeatureAnnotation).mapItem
        
        self.city = mapItem?.placemark.locality
        self.state = mapItem?.placemark.administrativeArea
        self.country = mapItem?.placemark.country
        self.countryCode = mapItem?.placemark.isoCountryCode
        self.mapItemIdentifier = mapItem?.identifier?.rawValue
        self.pointOfInterestCategory = mapItem?.pointOfInterestCategory?.rawValue
        self.phoneNumber = mapItem?.phoneNumber
        self.url = mapItem?.url
        self.timeZoneIdentifier = mapItem?.timeZone?.identifier
    }

    /// Returns ShazamStreams at a Spot, in an event, OR all if event is nil
    public func shazamStreamsByEvent(_ event: Event?) -> [ShazamStream] {
        if event == nil { return shazamStreams ?? [] }

        return shazamStreams?.filter { $0.event == event } ?? []
    }

    static var preview: Spot {
        Spot(name: "Sioux Falls", symbol: "magnifyingglass", latitude: 37.3316876, longitude: -122.0327261, shazamStreams: [ShazamStream.preview])
    }
}

/// Transformer for UIColor, using NSSecureUnarchiveFromData
@objc(UIColorValueTransformer)
final class UIColorValueTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return UIColor.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let color = value as? UIColor else { return nil }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
            return data
        } catch {
            return nil
        }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }

        do {
            let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
            return color
        } catch {
            return nil
        }
    }
}
