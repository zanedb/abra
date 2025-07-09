//
//  Event.swift
//  Abra
//

import Foundation
import SwiftData

@Model final class Event {
    var name: String = ""
    var spot: Spot?

    @Relationship(deleteRule: .nullify, inverse: \ShazamStream.event)
    var shazamStreams: [ShazamStream]? = [ShazamStream]()
    
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(name: String = "", spot: Spot, shazamStreams: [ShazamStream] = []) {
        self.name = name
        self.spot = spot
        self.shazamStreams = shazamStreams
    }
}
