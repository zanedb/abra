//
//  MKPointOfInterestCategory+symbol.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 1/1/26.
//

import Foundation
import MapKit

extension MKPointOfInterestCategory {
    /// Maps to an appropriate SFSymbol name string
    /// https://developer.apple.com/documentation/mapkit/
    var symbol: String {
        switch self {
        // Arts and culture
        case .museum: return "building"
        case .musicVenue: return "music.note"
        case .theater: return "theatermasks.fill"
        // Education
        case .library: return "books.vertical.fill"
        case .planetarium: return "moon.stars.fill"
        case .school: return "building.columns.fill"
        case .university: return "graduationcap.fill"
        // Entertainment
        case .movieTheater: return "film"
        case .nightlife: return "laser.burst"
        // Health and safety
        case .fireStation: return "flame.fill"
        case .hospital: return "cross.fill"
        case .pharmacy: return "pills.fill"
        case .police: return "shield.lefthalf.filled"
        // Historical and cultural landmarks
        case .castle: return "building.columns.fill"
        case .fortress: return "building.columns.fill"
        case .landmark: return "star.fill"
        case .nationalMonument: return "star.fill"
        // Food and drink
        case .bakery: return "cloud.fill"
        case .brewery: return "mug.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .distillery: return "mug.fill"
        case .foodMarket: return "basket.fill"
        case .restaurant: return "fork.knife"
        case .winery: return "wineglass.fill"
        // Personal services
        case .animalService: return "pawprint.fill"
        case .atm: return "creditcard.fill"
        case .automotiveRepair: return "book.and.wrench.fill"
        case .bank: return "dollarsign.bank.building.fill"
        case .beauty: return "comb.fill"
        case .evCharger: return "bolt.car.fill"
        case .fitnessCenter: return "dumbbell.fill"
        case .laundry: return "hanger"
        case .mailbox: return "envelope.fill"
        case .postOffice: return "envelope.fill"
        case .restroom: return "figure.stand.dress.line.vertical.figure"
        case .spa: return "cloud.fill"
        case .store: return "bag.fill"
        // Parks and recreation
        case .amusementPark: return "flag.2.crossed.fill"
        case .aquarium: return "fish.fill"
        case .beach: return "beach.umbrella.fill"
        case .campground: return "tent.fill"
        case .fairground: return "tent.2.fill"
        case .marina: return "sailboat.fill"
        case .nationalPark: return "tree.fill"
        case .park: return "tree.fill"
        case .rvPark: return "truck.pickup.side.fill"
        case .zoo: return "tortoise.fill"
        // Sports
        case .baseball: return "baseball.fill"
        case .basketball: return "basketball.fill"
        case .bowling: return "figure.bowling"
        case .goKart: return "flag.pattern.checkered.2.crossed"
        case .golf: return "flag.fill"
        case .hiking: return "mountain.2.fill"
        case .miniGolf: return "flag.fill"
        case .rockClimbing: return "figure.climbing"
        case .skatePark: return "figure.skateboarding"
        case .skating: return "figure.ice.skating"
        case .skiing: return "figure.skiing.crosscountry"
        case .soccer: return "soccerball"
        case .stadium: return "sportscourt.fill"
        case .tennis: return "tennis.racket"
        case .volleyball: return "volleyball.fill"
        // Travel
        case .airport: return "airplane"
        case .carRental: return "car.fill"
        case .conventionCenter: return "theatermask.and.paintbrush.fill"
        case .gasStation: return "fuelpump.fill"
        case .hotel: return "bed.double.fill"
        case .parking: return "parkingsign"
        case .publicTransport: return "tram.fill"
        // Water sports
        case .fishing: return "figure.fishing"
        case .kayaking: return "figure.outdoor.rowing"
        case .surfing: return "figure.surfing"
        case .swimming: return "figure.pool.swim"
        default: return "mappin"
        }
    }
    
    // TODO: color
}
