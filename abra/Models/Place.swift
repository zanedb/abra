//
//  Place.swift
//  abra
//
//  Created by Zane on 6/22/23.
//

import Foundation
import CoreData
import MapKit

extension Place: MKAnnotation {
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
    // for annotation callout view
    public var title: String? {
        return ""
    }
    
    // see https://www.timekl.com/blog/2017/04/02/putting-core-data-on-the-map/
    class func keyPathsForValuesAffectingCoordinate() -> Set<String> {
        return Set<String>([ #keyPath(latitude), #keyPath(longitude) ])
    }
}

extension Place {
    static var example: Place {
        let viewContext: NSManagedObjectContext = PersistenceController.preview.container.viewContext
        let newPlace = Place(context: viewContext)
        
        newPlace.city = "Cupertino"
        newPlace.country = "United States"
        newPlace.countryCode = "US"
        newPlace.state = "California"
        newPlace.latitude = 37.3316876
        newPlace.longitude = -122.0327261
        
        newPlace.createdAt = Date()
        newPlace.updatedAt = Date()
        
        newPlace.iconName = "magnifyingglass"
        newPlace.colorName = "blue"
        newPlace.name = "Sioux Falls"
        
        return newPlace
    }
}
