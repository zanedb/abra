//
//  SheetProvider.swift
//  Abra
//

import SwiftUI

/// Presents a single sheet out of two data sources
/// A possible ShazamStream, Spot can be selected
/// When one is selected (not nil), it is shown
/// When multiple are selected, Spot takes priority over ShazamStream
/// When a sheet is dismissed, all are deselected
@Observable final class SheetProvider {
    var stream: ShazamStream?
    var spot: Spot?
    var detent: PresentationDetent = .fraction(0.50)

    enum ViewState: Equatable {
        case none
        case stream(ShazamStream)
        case spot(Spot)
    }

    var now: ViewState {
        get {
            if spot != nil {
                return .spot(spot!)
            } else if stream != nil {
                return .stream(stream!)
            } else {
                return .none
            }
        } set {
            if newValue == .none {
                stream = nil
                spot = nil
                detent = .fraction(0.50)
            }
        }
    }

    var isPresented: Bool { now != .none }
    
    func show(_ spot: Spot) {
        self.spot = spot
        stream = nil
        detent = .fraction(0.50)
    }
    
    func show(_ stream: ShazamStream) {
        self.stream = stream
        spot = nil
        detent = .fraction(0.50)
    }
}
