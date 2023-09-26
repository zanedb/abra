//
//  ViewModel.swift
//  abra
//
//  Created by Zane on 7/6/23.
//

import Foundation
import SwiftUI
import SwiftData
import ShazamKit
import CoreData
import Combine
import MapKit

struct MatchResult: Identifiable, Equatable {
    let id = UUID()
    let match: SHMatch?
}

@MainActor final class ViewModel: ObservableObject {
    var modelContext: ModelContext? = nil
    
    private var location: Location = Location.shared
    
    @Published var selectedDetent: PresentationDetent = PresentationDetent.fraction(0.5)
    @Published var isMatching = false
    @Published var currentMatchResult: MatchResult?
    
    var currentMediaItem: SHMatchedMediaItem? {
        currentMatchResult?.match?.mediaItems.first
    }
    
    private let session: SHManagedSession
    
    init() {
        session = SHManagedSession()
        prepare()
    }
    
    private func prepare() {
        Task { @MainActor in
            await session.prepare()
        }
        location.requestLocation()
    }
    
    func match() async {
        isMatching = true
        location.requestLocation() // we'll need this soon
        
        for await result in session.results {
            switch result {
            case .match(let match):
                Task { @MainActor in
                    self.currentMatchResult = MatchResult(match: match)
                    print(currentMediaItem?.title ?? "nuttin")
                    await createShazamStream(currentMediaItem)
                    try await addToShazamLibrary(mediaItems: currentMatchResult?.match?.mediaItems ?? [])
                }
            case .noMatch(_):
                print("No match found")
                endSession()
            case .error(let error, _):
                print("Error \(error.localizedDescription)")
                endSession()
            }
            stopRecording()
        }
    }
    
    func createShazamStream(_ result: SHMatchedMediaItem?) async {
        if result == nil { return }
        
        let newShazamStream = ShazamStream(
            title: (result?.title)!, artist: (result?.artist)!, isExplicit: result!.explicitContent, artworkURL: (result?.artworkURL)!, timestamp: .now,
            latitude: (location.lastSeenLocation?.coordinate.latitude)!, longitude: (location.lastSeenLocation?.coordinate.longitude)!)
        
        newShazamStream.isrc = result?.isrc
        newShazamStream.shazamID = result?.shazamID
        newShazamStream.appleMusicID = result?.appleMusicID
        newShazamStream.appleMusicURL = result?.appleMusicURL
        
        newShazamStream.altitude = location.currentPlacemark?.location?.altitude
        newShazamStream.speed = location.currentPlacemark?.location?.speed
        newShazamStream.state = location.currentPlacemark?.administrativeArea
        newShazamStream.city = location.currentPlacemark?.locality
        newShazamStream.country = location.currentPlacemark?.country
        newShazamStream.countryCode = location.currentPlacemark?.isoCountryCode
        
        modelContext?.insert(newShazamStream)
        try? modelContext?.save()
    }
    
    func addToShazamLibrary(mediaItems: [SHMediaItem]) async throws {
        try await SHLibrary.default.addItems(mediaItems)
    }
    
    func stopRecording() {
        session.cancel()
        isMatching = false
        prepare()
    }
    
    func endSession() {
        // Reset result of any previous match
        isMatching = false
        currentMatchResult = MatchResult(match: nil)
    }
    
    }
}
