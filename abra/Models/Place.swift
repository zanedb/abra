//
//  Place.swift
//  abra
//
//  Created by Zane on 6/22/23.
//

import Foundation
import CoreData

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
