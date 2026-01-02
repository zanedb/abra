//
//  MKPointOfInterestCategory+symbol.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 1/1/26.
//

import Foundation
import MapKit

extension MKPointOfInterestCategory {
    /// Maps MKPointOfInterestCategory to an appropriate SFSymbol name string
    /// https://developer.apple.com/documentation/mapkit/mkpointofinterestcategory
    var symbol: String {
        switch self {
        // Arts and culture
        case MKPointOfInterestCategory.museum: return "building"
        case MKPointOfInterestCategory.musicVenue: return "music.note"
        case MKPointOfInterestCategory.theater: return "theatermasks.fill"
        // Education
        case MKPointOfInterestCategory.library: return "books.vertical.fill"
        case MKPointOfInterestCategory.planetarium: return "moon.stars.fill"
        case MKPointOfInterestCategory.school: return "pencil.and.ruler.fill"
        case MKPointOfInterestCategory.university: return "graduationcap.fill"
        // Entertainment
        case MKPointOfInterestCategory.movieTheater: return "film"
        case MKPointOfInterestCategory.nightlife: return "theatermask.and.paintbrush.fill"
        // Health and safety
        case MKPointOfInterestCategory.fireStation: return "flame.fill"
        case MKPointOfInterestCategory.hospital: return "cross.case.fill"
        case MKPointOfInterestCategory.pharmacy: return "pills.fill"
        case MKPointOfInterestCategory.police: return "shield.lefthalf.filled"
        // Historical and cultural landmarks
        case MKPointOfInterestCategory.castle: return "building.columns.fill"
        case MKPointOfInterestCategory.fortress: return "building.columns.fill"
        case MKPointOfInterestCategory.landmark: return "star.fill"
        case MKPointOfInterestCategory.nationalMonument: return "star.fill"
        // Food and drink
        case MKPointOfInterestCategory.bakery: return "cloud.fill"
        case MKPointOfInterestCategory.brewery: return "mug.fill"
        case MKPointOfInterestCategory.cafe: return "cup.and.saucer.fill"
        case MKPointOfInterestCategory.distillery: return "mug.fill"
        case MKPointOfInterestCategory.foodMarket: return "cart.fill"
        case MKPointOfInterestCategory.restaurant: return "fork.knife"
        case MKPointOfInterestCategory.winery: return "wineglass.fill"
        // Personal services
        case MKPointOfInterestCategory.animalService: return "pawprint.fill"
        case MKPointOfInterestCategory.atm: return "creditcard.fill"
        case MKPointOfInterestCategory.automotiveRepair: return "book.and.wrench.fill"
        case MKPointOfInterestCategory.bank: return "building.columns.fill"
        case MKPointOfInterestCategory.beauty: return "comb.fill"
        case MKPointOfInterestCategory.evCharger: return "bolt.car.fill"
        case MKPointOfInterestCategory.fitnessCenter: return "dumbbell.fill"
        case MKPointOfInterestCategory.laundry: return "hanger"
        case MKPointOfInterestCategory.mailbox: return "envelope.fill"
        case MKPointOfInterestCategory.postOffice: return "envelope.fill"
        case MKPointOfInterestCategory.restroom: return "figure.stand.dress.line.vertical.figure"
        case MKPointOfInterestCategory.spa: return "cloud.fill"
        case MKPointOfInterestCategory.store: return "bag.fill"
        // Parks and recreation
        case MKPointOfInterestCategory.amusementPark: return "flag.2.crossed.fill"
        case MKPointOfInterestCategory.aquarium: return "fish.fill"
        case MKPointOfInterestCategory.beach: return "beach.umbrella.fill"
        case MKPointOfInterestCategory.campground: return "tent.fill"
        case MKPointOfInterestCategory.fairground: return "tent.2.fill"
        case MKPointOfInterestCategory.marina: return "sailboat.fill"
        case MKPointOfInterestCategory.nationalPark: return "tree.fill"
        case MKPointOfInterestCategory.park: return "tree.fill"
        case MKPointOfInterestCategory.rvPark: return "truck.pickup.side.fill"
        case MKPointOfInterestCategory.zoo: return "tortoise.fill"
        // Sports
        case MKPointOfInterestCategory.baseball: return "baseball.fill"
        case MKPointOfInterestCategory.basketball: return "basketball.fill"
        case MKPointOfInterestCategory.bowling: return "figure.bowling"
        case MKPointOfInterestCategory.goKart: return "flag.pattern.checkered.2.crossed"
        case MKPointOfInterestCategory.golf: return "flag.fill"
        case MKPointOfInterestCategory.hiking: return "mountain.2.fill"
        case MKPointOfInterestCategory.miniGolf: return "flag.fill"
        case MKPointOfInterestCategory.rockClimbing: return "figure.climbing"
        case MKPointOfInterestCategory.skatePark: return "figure.skateboarding"
        case MKPointOfInterestCategory.skating: return "figure.ice.skating"
        case MKPointOfInterestCategory.skiing: return "figure.skiing.crosscountry"
        case MKPointOfInterestCategory.soccer: return "soccerball"
        case MKPointOfInterestCategory.stadium: return "sportscourt.fill"
        case MKPointOfInterestCategory.tennis: return "tennis.racket"
        case MKPointOfInterestCategory.volleyball: return "volleyball.fill"
        // Travel
        case MKPointOfInterestCategory.airport: return "airplane"
        case MKPointOfInterestCategory.carRental: return "car.fill"
        case MKPointOfInterestCategory.conventionCenter: return "theatermask.and.paintbrush.fill"
        case MKPointOfInterestCategory.gasStation: return "fuelpump.fill"
        case MKPointOfInterestCategory.hotel: return "bed.double.fill"
        case MKPointOfInterestCategory.parking: return "parkingsign"
        case MKPointOfInterestCategory.publicTransport: return "tram.fill"
        // Water sports
        case MKPointOfInterestCategory.fishing: return "figure.fishing"
        case MKPointOfInterestCategory.kayaking: return "figure.outdoor.rowing"
        case MKPointOfInterestCategory.surfing: return "figure.surfing"
        case MKPointOfInterestCategory.swimming: return "figure.pool.swim"
        default: return "mappin"
        }
    }
    
    // TODO: color
}
