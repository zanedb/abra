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
import GeoToolbox

@Model final class ShazamStream {
    // Identifies one captured listen across stores; Shazam IDs identify songs.
    var matchID: UUID?
    var timestamp: Date = Date.now
    var note: String = ""

    // SHMediaItem
    var title: String = ""
    var subtitle: String?
    var artist: String = ""
    var artworkURL: URL = URL(
        string:
            "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png"
    )!
    var videoURL: URL?
    var isExplicit: Bool = false
    var creationDate: Date?
    var isrc: String?
    var shazamLibraryID: UUID?  // SHMediaItem.id
    var appleMusicURL: URL?
    var appleMusicID: String?
    var webURL: URL?
    var shazamID: String?
    // CloudKit-compatible range storage as JSON Data
    var timeRangesData: Data = Data()
    var frequencySkewRangesData: Data = Data()

    // CLLocation
    var latitude: Double = 0 // join me in null island..
    var longitude: Double = 0
    var altitude: CLLocationDistance?
    var isProducedByAccessory: Bool?
    var isSimulatedBySoftware: Bool?
    var horizontalAccuracy: CLLocationAccuracy?
    var locationObservedAt: Date?
    var verticalAccuracy: CLLocationAccuracy?
    var speed: CLLocationSpeed?
    var speedAccuracy: CLLocationSpeedAccuracy?
    var course: CLLocationDirection?
    var courseAccuracy: CLLocationDirectionAccuracy?

    // CLPlacemark
    var placemarkName: String?  // CLPlacemark.name
    var thoroughfare: String?  // Street address
    var subThoroughfare: String?  // Street number
    var city: String?  // CLPlacemark.locality
    var subLocality: String?  // Neighborhood
    var state: String?  // CLPlacemark.administrativeArea, state/province
    var subAdministrativeArea: String?  // County
    var postalCode: String?
    var countryCode: String?  // CLPlacemark.isoCountryCode
    var country: String?
    var inlandWater: String?  // Body of water, if above one
    var ocean: String?  // If above one
    var timeZoneIdentifier: String?

    // Motion
    var motionActivity: String?

    // Relations
    var spot: Spot?

    init(mediaItem: SHMediaItem, location: CLLocation?, placemark: CLPlacemark?, motionActivity: String? = nil)
    {
        self.matchID = UUID()
        self.timestamp = .now

        // SHMediaItem
        self.title = mediaItem.title ?? "Unknown Title"
        self.subtitle = mediaItem.subtitle
        self.artist = mediaItem.artist ?? "Unknown Artist"
        self.artworkURL =
            mediaItem.artworkURL ?? URL(
                string: "https://zane.link/abra-unavailable"
            )!
        self.videoURL = mediaItem.videoURL
        self.isExplicit = mediaItem.explicitContent
        self.creationDate = mediaItem.creationDate
        self.isrc = mediaItem.isrc
        self.shazamLibraryID = mediaItem.id
        self.appleMusicURL = mediaItem.appleMusicURL
        self.appleMusicID = mediaItem.appleMusicID
        self.webURL = mediaItem.webURL
        self.shazamID = mediaItem.shazamID
        // Set ranges using computed properties
        self.timeRanges = mediaItem.timeRanges
        self.frequencySkewRanges = mediaItem.frequencySkewRanges

        // Motion
        self.motionActivity = motionActivity

        // CLLocation
        self.latitude = location?.coordinate.latitude ?? 0
        self.longitude = location?.coordinate.longitude ?? 0
        self.altitude = location?.altitude
        self.isProducedByAccessory =
            location?.sourceInformation?.isProducedByAccessory
        self.isSimulatedBySoftware =
            location?.sourceInformation?.isSimulatedBySoftware
        self.horizontalAccuracy = location?.horizontalAccuracy
        self.locationObservedAt = location?.timestamp
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
        self.timeZoneIdentifier = placemark?.timeZone?.identifier
    }

    // .preview initializer
    init(
        title: String = "",
        artist: String = "",
        isExplicit: Bool = false,
        artworkURL: URL = URL(
            string:
                "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png"
        )!,
        latitude: Double = 37.721941,
        longitude: Double = -122.4739084,
        appleMusicID: String? = nil,
        appleMusicURL: URL? = nil
    ) {
        self.timestamp = .now
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.isExplicit = isExplicit
        // Initialize empty ranges
        self.timeRanges = []
        self.frequencySkewRanges = []
        self.latitude = latitude
        self.longitude = longitude
        self.appleMusicID = appleMusicID
        self.appleMusicURL = appleMusicURL
    }
}

extension ShazamStream {
    // CloudKit-compatible Range computed properties
    var timeRanges: [Range<TimeInterval>] {
        get {
            guard !timeRangesData.isEmpty,
                  let ranges = try? JSONDecoder().decode([[Double]].self, from: timeRangesData) else {
                return []
            }
            return ranges.compactMap { array in
                guard array.count >= 2 else { return nil }
                return Range(uncheckedBounds: (lower: array[0], upper: array[1]))
            }
        }
        set {
            let rangeArrays = newValue.map { [$0.lowerBound, $0.upperBound] }
            timeRangesData = (try? JSONEncoder().encode(rangeArrays)) ?? Data()
        }
    }

    var frequencySkewRanges: [Range<Float>] {
        get {
            guard !frequencySkewRangesData.isEmpty,
                  let ranges = try? JSONDecoder().decode([[Float]].self, from: frequencySkewRangesData) else {
                return []
            }
            return ranges.compactMap { array in
                guard array.count >= 2 else { return nil }
                return Range(uncheckedBounds: (lower: array[0], upper: array[1]))
            }
        }
        set {
            let rangeArrays = newValue.map { [$0.lowerBound, $0.upperBound] }
            frequencySkewRangesData = (try? JSONEncoder().encode(rangeArrays)) ?? Data()
        }
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// A conservative display estimate, not a claim that the song was heard
    /// at the saved coordinate. Older and manually placed locations without a
    /// measured accuracy continue to use their existing map appearance.
    public var approximateLocationRadius: CLLocationDistance? {
        guard latitude != 0 || longitude != 0,
              let accuracy = horizontalAccuracy,
              accuracy.isFinite,
              accuracy > 0 else { return nil }

        let signedAge = timestamp.timeIntervalSince(locationObservedAt ?? timestamp)
        // Automatic post-match recovery is bounded to 30 seconds. Older manual
        // corrections stored the edit time here, sometimes days after the song;
        // that gap is not evidence of travel and must not create a giant radius.
        let observedAfterMatch = signedAge < 0 && signedAge >= -30
        let age = signedAge >= 0 ? signedAge : (observedAfterMatch ? -signedAge : 0)
        let possibleMetersPerSecond: Double
        switch motionActivity {
        case "automotive": possibleMetersPerSecond = 20
        case "cycling": possibleMetersPerSecond = 6
        case "stationary": possibleMetersPerSecond = 0
        default: possibleMetersPerSecond = observedAfterMatch ? 20 : 1.5
        }
        // Confirmed stationary motion should not turn a six-metre GPS fix into
        // a neighbourhood-sized estimate merely because its timestamp aged.
        // Ignore noisy GPS speed while Core Motion confirms no movement.
        let movementSpeed = motionActivity == "stationary" ? 0 : max(possibleMetersPerSecond, speed ?? 0)
        let radius = accuracy + age * movementSpeed
        // Later observations normally need a movement margin. A short cold-start
        // grace below allows a precise fix without evidence of travel to attach.
        if observedAfterMatch && motionActivity != "stationary" {
            // Cold GPS acquisition often finishes just after a match. Accept a
            // short, precise observation as the capture's position unless motion
            // or measured speed indicates travel. Preserve its real timestamp.
            if Self.acceptsEarlyPreciseFix(accuracy: accuracy, speed: speed,
                motionActivity: motionActivity, delay: age) { return nil }
            return max(50, radius)
        }
        return radius >= 50 ? radius : nil
    }

    static func acceptsEarlyPreciseFix(accuracy: Double, speed: Double?,
                                      motionActivity: String?, delay: TimeInterval) -> Bool {
        let moving = ["automotive", "cycling", "running", "walking"].contains(motionActivity ?? "")
        return (0...15).contains(delay) && accuracy >= 0 && accuracy < 50
            && !moving && (speed ?? -1) <= 1.5
    }

    public var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0.0,
            horizontalAccuracy: horizontalAccuracy ?? 0.0,
            verticalAccuracy: verticalAccuracy ?? 0.0,
            course: course ?? 0.0,
            courseAccuracy: courseAccuracy ?? 0.0,
            speed: speed ?? 0.0,
            speedAccuracy: speedAccuracy ?? 0.0,
            timestamp: timestamp
        )
    }
    
    /*
    @available(iOS 26.0, *)
    public var placeDescriptor: PlaceDescriptor {
        PlaceDescriptor(
            representations: [.deviceLocation(location)],
            commonName: <#T##String?#>
        )
    }
    
    
    let request = MKMapItemRequest(placeDescriptor: placeDescriptor)
    mapItem = try await request.mapItem
     */

    public var cityState: String {
        if let city = city, let state = state {
            "\(city), \(state)"
        } else if let city = city {
            city
        } else if let neighborhood = subLocality {
            neighborhood
        } else if let state = state {
            state
        } else if let country = country {
            country
        } else {
            "Location unavailable"
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

    /// Place; i.e. "Mission" or "San Francisco" or "1015"
    public var place: String {
        spotName ?? subLocality ?? city ?? country ?? "Unknown"
    }

    /// A Spot name suitable for display, excluding empty draft names.
    public var spotName: String? {
        guard let name = spot?.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !name.isEmpty else {
            return nil
        }
        return name
    }

    /// Place; i.e. "in San Francisco," "at 1015"
    public var attributedPlace: String {
        "\(spotName != nil ? "at" : "in") \(spotName ?? city ?? "Unknown")"
    }

    /// Description; i.e. "August 11 in San Francisco", "July 4 at 1015"
    public var description: String {
        let date = self.date

        return "\(date) \(attributedPlace)"
    }

    /// Song.link URL
    public var songLink: URL? {
        guard let url = appleMusicURL?.absoluteString else { return nil }
        return URL(string: "https://song.link/\(url)")
    }

    public func distance(from other: ShazamStream) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(
            latitude: other.latitude,
            longitude: other.longitude
        )

        return location1.distance(from: location2)
    }

    /// Updates location, using Placemark data as well if possible
    public func updateLocation(
        _ location: CLLocation,
        placemark: CLPlacemark? = nil
    ) {
        // CLLocation
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        isProducedByAccessory =
            location.sourceInformation?.isProducedByAccessory
        isSimulatedBySoftware =
            location.sourceInformation?.isSimulatedBySoftware
        horizontalAccuracy = location.horizontalAccuracy
        locationObservedAt = location.timestamp
        verticalAccuracy = location.verticalAccuracy
        speed = location.speed
        speedAccuracy = location.speedAccuracy
        course = location.course
        courseAccuracy = location.courseAccuracy

        updatePlacemark(placemark)
    }

    public func updatePlacemark(_ placemark: CLPlacemark?) {
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
        timeZoneIdentifier = placemark?.timeZone?.identifier
    }

    enum LocationEditError: LocalizedError {
        case songUnavailable
        var errorDescription: String? { "This song is no longer available. Close it and try again." }
    }

    /// Commit through a separate context before changing the displayed model.
    /// A failed save must not alter its location/Spot, or roll back unrelated notes.
    @MainActor
    func saveLocationEdit(_ changes: (ShazamStream, ModelContext) -> Void) throws {
        guard let owner = modelContext, !isDeleted else { throw LocationEditError.songUnavailable }
        let id = persistentModelID
        let editingContext = ModelContext(owner.container)
        editingContext.autosaveEnabled = false
        let descriptor = FetchDescriptor<ShazamStream>(predicate: #Predicate { $0.persistentModelID == id })
        guard let copy = try editingContext.fetch(descriptor).first else {
            throw LocationEditError.songUnavailable
        }
        changes(copy, editingContext)
        try editingContext.save()
        // Keep the existing SwiftUI-bound instance current only after the write
        // succeeds. Run the same location-only edit in its owning context.
        changes(self, owner)
        // Keep the displayed observation provenance identical to the committed edit.
        locationObservedAt = copy.locationObservedAt
    }

    /// An explicit correction replaces any previously associated venue.
    public func setLocationFromPicker(_ location: CLLocation, placemark: CLPlacemark? = nil,
                                      context: ModelContext? = nil, allowSpot: Bool = true) {
        spot = nil
        updateLocation(location, placemark: placemark)
        // This is the user's explicit assignment for the song, not an automatic
        // observation of where they were at recognition time. Don't project the
        // time between an old song and today's correction into its uncertainty.
        locationObservedAt = nil
        // An explicitly chosen venue is precise even under reduced GPS permission.
        // Current Location must additionally honor that permission's accuracy mode.
        if allowSpot, location.horizontalAccuracy >= 0, location.horizontalAccuracy < 50,
           approximateLocationRadius == nil, let context {
            spotIt(context: context)
        }
    }

    public func setLocationFromPicker(_ mapItem: MKMapItem, context: ModelContext? = nil) {
        let coordinate = mapItem.placemark.coordinate
        setLocationFromPicker(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            placemark: mapItem.placemark, context: context
        )
        placemarkName = mapItem.name ?? mapItem.placemark.name
    }

    /// Find Spots that are super close by and save to automagically.
    /// Queries for lat/long within three decimal sig figs of precision.
    public func spotIt(context: ModelContext) {
        // A nearby center alone is not evidence that an uncertain fix was at a venue.
        guard approximateLocationRadius == nil else { return }
        let precision = 0.001
        let halfPrecision = precision / 2

        let latMin = latitude - halfPrecision
        let latMax = latitude + halfPrecision
        let lonMin = longitude - halfPrecision
        let lonMax = longitude + halfPrecision

        let predicate = #Predicate<Spot> {
            $0.latitude >= latMin && $0.latitude < latMax
                && $0.longitude >= lonMin && $0.longitude < lonMax
        }

        let fetchDescriptor = FetchDescriptor<Spot>(predicate: predicate)

        do {
            let spots = try context.fetch(fetchDescriptor)
            for item in spots {
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
            artworkURL: URL(
                string:
                    "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png"
            )!,
            latitude: 37.721941,
            longitude: -122.4739084,
            appleMusicID: "1613567102",
            appleMusicURL: URL(string: "https://music.apple.com/us/album/the-ills/1613566792?i=1613567102")!
        )
    }
}
