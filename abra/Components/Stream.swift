//
//  Stream.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import Foundation
import MapKit

extension SStream: MKAnnotation {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}

extension SStream {
    static var example: SStream {
        //var viewContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext
        let newItem = SStream()
        
        newItem.latitude = 37.3316876
        newItem.longitude = -122.0327261
        newItem.altitude = 0
        newItem.speed = -1
        newItem.state = "California"
        newItem.city = "Cupertino"
        newItem.country = "United States"
        
        newItem.artist = "JTMC"
        newItem.trackTitle = "Woohwaaahwooh"
        newItem.explicitContent = false
        newItem.artworkURL = URL(string: "https://hws.dev/paul.jpg")
        newItem.isrc = ""
        newItem.shazamID = ""
        newItem.appleMusicID = ""
        newItem.appleMusicURL = URL(string: "https://music.apple.com/us/album/kiss-of-life/1524651367?i=1524651852&itscg=30201&itsct=bglsk")
        
        return newItem
    }
}
