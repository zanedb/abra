//
//  ViewModel.swift
//  Abra
//

import Foundation
import SwiftUI
import SwiftData
import ShazamKit
import CoreData
import Combine
import MapKit
import ActivityKit

struct MatchResult: Identifiable, Equatable {
    let id = UUID()
    let match: SHMatch?
}

@MainActor final class ViewModel: ObservableObject {
    var modelContext: ModelContext? = nil
    
    private var location: Location = Location.shared
    
    @Published var selectedDetent: PresentationDetent = PresentationDetent.fraction(0.5)
    @Published var selectedSS: ShazamStream?
    @Published var mapSelection: PersistentIdentifier?
    @Published var isMatching = false
    @Published var currentMatchResult: MatchResult?
    @Published private(set) var isActivityRunning: Bool = false
    
    private var currentActivity: Activity<WidgetAttributes>? = nil
    
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
        startActivity()
        
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
        
        if (location.lastSeenLocation?.coordinate.latitude == nil || location.lastSeenLocation?.coordinate.longitude == nil) {
            print("Couldn't get location in time")
            // TODO: actually handle this
            return // MARK: prevent a crash
        }
        
        let newShazamStream = ShazamStream(
            title: (result?.title)!, artist: (result?.artist)!, isExplicit: result!.explicitContent, artworkURL: (result?.artworkURL)!,
            latitude: (location.lastSeenLocation?.coordinate.latitude)!, longitude: (location.lastSeenLocation?.coordinate.longitude)!)
        
        newShazamStream.isrc = result?.isrc
        newShazamStream.shazamID = result?.shazamID
        newShazamStream.shazamLibraryID = result?.id
        newShazamStream.appleMusicID = result?.appleMusicID
        newShazamStream.appleMusicURL = result?.appleMusicURL
        
        newShazamStream.altitude = location.currentPlacemark?.location?.altitude
        newShazamStream.speed = location.currentPlacemark?.location?.speed
        
        newShazamStream.thoroughfare = location.currentPlacemark?.thoroughfare
        newShazamStream.city = location.currentPlacemark?.locality
        newShazamStream.state = location.currentPlacemark?.administrativeArea
        newShazamStream.country = location.currentPlacemark?.country
        newShazamStream.countryCode = location.currentPlacemark?.isoCountryCode
        
        modelContext?.insert(newShazamStream)
        try? modelContext?.save()
    }
    
    func addToShazamLibrary(mediaItems: [SHMediaItem]) async throws {
        try await SHLibrary.default.addItems(mediaItems)
    }
    
    func deleteFromShazamLibrary(_ stream: ShazamStream) async throws {
        guard let mediaItem = SHLibrary.default.items.filter({ $0.id == stream.shazamLibraryID }).first else { return } // obtain reference to same object
        try await SHLibrary.default.removeItems([mediaItem])
    }
    
    func stopRecording() {
        session.cancel()
        isMatching = false
        endActivity()
    }
    
    private func endSession() {
        // Reset result of any previous match
        isMatching = false
        endActivity()
        currentMatchResult = MatchResult(match: nil)
    }
    
    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        do {
            let attributes = WidgetAttributes()
            let initialState = WidgetAttributes.ContentState(
                takingTooLong: false
            )
            
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            currentActivity = activity
            isActivityRunning = true
            
            print("Started activity with ID: \(activity.id)")
        } catch {
            print("Error starting Live Activity: \(error)")
        }
    }
    
    private func updateActivity(takingTooLong: Bool) {
        Task {
            guard let activity = currentActivity else { return }
            
            let updatedState = WidgetAttributes.ContentState(takingTooLong: takingTooLong)
            
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            print("Updated activity with ID: \(activity.id)")
        }
    }
    
    private func endActivity() {
        Task {
            guard let activity = currentActivity else { return }
            
            let dismissalPolicy = ActivityUIDismissalPolicy.default
            let finalState = WidgetAttributes.ContentState(takingTooLong: false)
            
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: dismissalPolicy)
            print("Ended activity with ID: \(activity.id)")
            
            currentActivity = nil
            isActivityRunning = false
        }
    }
}
