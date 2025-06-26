//
//  SheetProvider.swift
//  Abra
//

import SwiftUI

// Presents a single sheet out of three data sources
// A possible ShazamStream, ShazamStreamGroup, and Spot can all be selected
// When one is selected (not nil), it is shown
// When multiple are selected, Stream takes priority over Group takes priority over Spot
// When a sheet is dismissed, all are deselected
@Observable final class SheetProvider {
    var stream: ShazamStream? = nil
    var group: ShazamStreamGroup? = nil
    var spot: Spot? = nil
    
    var detent: PresentationDetent = .fraction(0.50)
    
    enum ViewState: Equatable {
        case none
        case stream(ShazamStream)
        case group(ShazamStreamGroup)
        case spot(Spot)
    }
    
    var now: ViewState {
        get {
            if (stream != nil) {
                return .stream(stream!)
            } else if (group != nil) {
                return .group(group!)
            } else if (spot != nil) {
                return .spot(spot!)
            } else {
                return .none
            }
        } set {
            if (newValue == .none) {
                stream = nil
                group = nil
                spot = nil
            }
        }
    }
    var isPresented: Bool { now != .none }
}
