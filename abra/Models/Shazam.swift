//
//  Shazam.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import Foundation
import CoreData
import AVKit
import ShazamKit
import Combine

class Shazam: NSObject, ObservableObject, SHSessionDelegate {
    
    @Published var currentItem: SHMediaItem? = nil
    @Published var searching = false
    
    private var viewContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    private var location: Location = Location.shared
    
    private let session = SHSession()
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        session.delegate = self
    }
    
    private func prepareAudioRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func generateSignature() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: .zero)
        
        inputNode.installTap(onBus: .zero, bufferSize: 1024, format: recordingFormat) { [weak session] buffer, _ in
            session?.matchStreamingBuffer(buffer, at: nil)
        }
    }
    
    private func startAudioRecording() throws {
        try audioEngine.start()
        searching = true
    }
    
    public func startRecognition() {
        // we'll need this soon
        location.requestLocation()
        
        do {
            if audioEngine.isRunning {
                stopRecognition()
                return
            }
            
            try prepareAudioRecording()
            generateSignature()
            try startAudioRecording()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func stopRecognition() {
        DispatchQueue.main.async {
            self.searching = false
        }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: .zero)
    }
    
    public func session(_ session: SHSession, didFind match: SHMatch) {
        guard let mediaItem = match.mediaItems.first else { return }
        
        // TODO: fix these two issues. should not be updating from a background thread.
        // MARK: this shit is important.
        
        DispatchQueue.main.async {
            self.currentItem = mediaItem
        }
        
        // create a new CoreData entry with all the metadata!
        let newItem = SStream(context: viewContext)
        
        newItem.timestamp = Date()
        
        if (location.authorizationStatus != .authorizedWhenInUse) {
            // todo handle
            print("LOCATION NOT AUTHORIZED")
        }
        
        newItem.latitude = location.lastSeenLocation?.coordinate.latitude ?? 0
        newItem.longitude = location.lastSeenLocation?.coordinate.longitude ?? 0
        newItem.altitude = location.lastSeenLocation?.altitude ?? 0
        newItem.speed = location.lastSeenLocation?.speed ?? 0
        newItem.state = location.currentPlacemark?.administrativeArea ?? ""
        newItem.city = location.currentPlacemark?.locality ?? ""
        newItem.country = location.currentPlacemark?.country ?? ""
        newItem.countryCode = location.currentPlacemark?.isoCountryCode ?? ""
        
        newItem.artist = mediaItem.artist
        newItem.trackTitle = mediaItem.title
        newItem.explicitContent = mediaItem.explicitContent
        newItem.artworkURL = mediaItem.artworkURL
        newItem.isrc = mediaItem.isrc
        newItem.shazamID = mediaItem.shazamID
        newItem.appleMusicID = mediaItem.appleMusicID
        newItem.appleMusicURL = mediaItem.appleMusicURL

        do {
            try viewContext.save()
            stopRecognition()
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}
