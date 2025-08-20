//
//  SheetProvider.swift
//  Abra
//

import SwiftUI
import MapKit
import Combine

/// Presents a single sheet out of two data sources
/// A possible ShazamStream, Spot can be selected
/// When one is selected (not nil), it is shown
/// When multiple are selected, Spot takes priority over ShazamStream
/// When a sheet is dismissed, all are deselected
@Observable final class SheetProvider {
    let didChange = PassthroughSubject<Void, Never>()

    var stream: ShazamStream?
    var spot: Spot?
    
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
                didChange.send()
            }
        }
    }
    
    var isPresentedBinding: Binding<Bool> { Binding<Bool>(
        get: { self.now != .none },
        set: { _ in
            self.now = .none
        })
    }
    
    var isPresented: Bool {
        self.now != .none
    }
    
    var coordinate: CLLocationCoordinate2D? {
        switch now {
        case .spot(let spot):
            return spot.coordinate
        case .stream(let stream):
            return stream.coordinate
        case .none:
            return nil
        }
    }
    
    func show(_ spot: Spot) {
        self.spot = spot
        stream = nil
        didChange.send()
    }
    
    func show(_ stream: ShazamStream) {
        self.stream = stream
        spot = nil
        didChange.send()
    }
}
