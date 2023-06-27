//
//  Stream.swift
//  abra
//
//  Created by Zane on 6/17/23.
//

import Foundation
import MapKit
import CoreData

extension SStream: MKAnnotation {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}


// TODO: create .artwork property that returns artwork view

extension SStream {
    
    
    static var example: SStream {
        let viewContext: NSManagedObjectContext = PersistenceController.preview.container.viewContext
        let newItem = SStream(context: viewContext)
        
        newItem.latitude = 37.3316876
        newItem.longitude = -122.0327261
        newItem.altitude = 0
        newItem.speed = -1
        newItem.state = "California"
        newItem.city = "Cupertino"
        newItem.country = "United States"
        newItem.countryCode = "US"
        newItem.timestamp = Date()
        
        newItem.artist = "JTMC"
        newItem.trackTitle = "Woohwaaahwooh"
        newItem.explicitContent = false
        newItem.artworkURL = URL(string: "https://hws.dev/paul.jpg")
        newItem.isrc = ""
        newItem.shazamID = ""
        newItem.appleMusicID = "1524651367"
        newItem.appleMusicURL = URL(string: "https://music.apple.com/us/album/kiss-of-life/1524651367?i=1524651852&itscg=30201&itsct=bglsk")
        
        return newItem
    }
}
