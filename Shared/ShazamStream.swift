//
//  ShazamStream.swift
//  Abra
//
//  The model class of ShazamStream (formerly SStream).
//

import Foundation
import SwiftData
import MapKit

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
    
    init(title: String = "", artist: String = "", isExplicit: Bool = false, artworkURL: URL = URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!, latitude: Double = 37.721941, longitude: Double = -122.4739084) {
        self.title = title
        self.artist = artist
        self.isExplicit = isExplicit
        self.timestamp = .now
        self.artworkURL = artworkURL
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension Date {
    func isInLastSevenDays() -> Bool {
        let now = Date()
        guard let aWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now) else { return false }
        return self <= now && self > aWeekAgo
    }
    
    func isInLastThirtyDays() -> Bool {
        let now = Date()
        guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) else { return false }
        return self <= now && self > thirtyDaysAgo
    }
    
    var month: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: self)
    }
    
    var timeSince: String {
        let rDF = RelativeDateTimeFormatter()
        rDF.unitsStyle = .abbreviated
        return rDF.localizedString(for: self, relativeTo: Date.now)
    }
    
    func relativeGroupString() -> String {
        if (Calendar.current.isDateInToday(self)) {
            return "Today"
        } else if(self.isInLastSevenDays()) {
            return "Last 7 Days"
        } else if(self.isInLastThirtyDays()) {
            return "Last 30 Days"
        } else {
            return self.month
        }
    }
}

extension ShazamStream {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
    public var cityState: String {
        if (city != nil && state != nil) {
            "\(city!), \(state!)"
        } else {
            "Unknown"
        }
    }
    
    public var relativeDateTime: String {
        if (timestamp.isInLastThirtyDays()) {
            timestamp.timeSince
        } else {
            timestamp.formatted(.dateTime.day().month())
        }
    }
    
    public var timeGroupedString: String {
        timestamp.relativeGroupString()
    }
    
    public var placeGroupedString: String {
        thoroughfare ?? "Unknown"
    }
    
    static var preview: ShazamStream {
        ShazamStream(title: "The Ills", artist: "Denzel Curry", isExplicit: true,
                     artworkURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!,
                     latitude: 37.721941, longitude: -122.4739084)
    }
}
