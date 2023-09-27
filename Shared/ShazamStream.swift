//
//  ShazamStream.swift
//  abra
//
//  The model class of ShazamStream (formerly SStream).
//
//  Created by Zane on 9/24/23.
//

import Foundation
import SwiftData
import MapKit

@Model final class ShazamStream {
    var title: String
    var artist: String
    var isExplicit: Bool
    var artworkURL: URL
    var timestamp: Date
    
    var isrc: String?
    var shazamID: String?
    var appleMusicID: String?
    var appleMusicURL: URL?
    
    var latitude: Double
    var longitude: Double
    var speed: Double?
    var altitude: Double?
    var city: String?
    var state: String?
    var country: String?
    var countryCode: String?
    
    init(title: String, artist: String, isExplicit: Bool, artworkURL: URL, latitude: Double, longitude: Double) {
        self.title = title
        self.artist = artist
        self.isExplicit = isExplicit
        self.timestamp = .now
        self.artworkURL = artworkURL
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension ShazamStream {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
    static var preview: ShazamStream {
        ShazamStream(title: "The Ills", artist: "Denzel Curry", isExplicit: true,
                     artworkURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/c/cf/Denzel_Curry_-_Melt_My_Eyez_See_Your_Future.png")!,
                     timestamp: .now, latitude: 37.721941, longitude: -122.4739084)
    }
}
