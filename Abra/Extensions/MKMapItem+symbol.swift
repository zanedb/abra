//
//  MKMapItem+.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 1/1/26.
//

import Foundation
import MapKit

extension MKMapItem {
    /// Maps MKPointOfInterestCategory to an appropriate SFSymbol name string
    var symbol: String {
        guard let value = pointOfInterestCategory else { return "mappin.and.ellipse" }
        switch value {
        case MKPointOfInterestCategory.museum: return "building"
        case MKPointOfInterestCategory.musicVenue: return "music.note"
        case MKPointOfInterestCategory.theater: return "theatermasks.fill"
        case MKPointOfInterestCategory.library: return "books.vertical.fill"
        case MKPointOfInterestCategory.planetarium: return "moon.stars.fill"
        case MKPointOfInterestCategory.school: return "pencil.and.ruler.fill"
        case MKPointOfInterestCategory.university: return "graduationcap.fill"
        case MKPointOfInterestCategory.nightlife: return "theatermask.and.paintbrush.fill"
        case MKPointOfInterestCategory.movieTheater: return "film.fill"
        case MKPointOfInterestCategory.airport: return "airplane"
        case MKPointOfInterestCategory.amusementPark: return "flag.2.crossed.fill"
        case MKPointOfInterestCategory.aquarium: return "fish.fill"
        case MKPointOfInterestCategory.atm: return "creditcard.fill"
        case MKPointOfInterestCategory.bank: return "building.columns.fill"
        case MKPointOfInterestCategory.beach: return "beach.umbrella.fill"
        case MKPointOfInterestCategory.brewery: return "wineglass.fill"
        case MKPointOfInterestCategory.cafe: return "cup.and.saucer.fill"
        case MKPointOfInterestCategory.campground: return "tent.fill"
        case MKPointOfInterestCategory.carRental: return "car.fill"
        case MKPointOfInterestCategory.evCharger: return "bolt.car.fill"
        case MKPointOfInterestCategory.fireStation: return "flame.fill"
        case MKPointOfInterestCategory.fitnessCenter: return "dumbbell.fill"
        case MKPointOfInterestCategory.gasStation: return "fuelpump.fill"
        case MKPointOfInterestCategory.hospital: return "cross.case.fill"
        case MKPointOfInterestCategory.hotel: return "bed.double.fill"
        case MKPointOfInterestCategory.marina: return "sailboat.fill"
        case MKPointOfInterestCategory.park: return "tree.fill"
        case MKPointOfInterestCategory.parking: return "parkingsign.circle.fill"
        case MKPointOfInterestCategory.pharmacy: return "pills.fill"
        case MKPointOfInterestCategory.police: return "shield.lefthalf.filled"
        case MKPointOfInterestCategory.postOffice: return "envelope.fill"
        case MKPointOfInterestCategory.restaurant: return "fork.knife"
        case MKPointOfInterestCategory.restroom: return "toilet.fill"
        case MKPointOfInterestCategory.store: return "bag.fill"
        case MKPointOfInterestCategory.zoo: return "pawprint.fill"
        default: return "mappin.and.ellipse"
        }
    }
}
