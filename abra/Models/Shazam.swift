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
    private var locationController = LocationController.shared
    
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
        searching = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: .zero)
    }
    
    public func session(_ session: SHSession, didFind match: SHMatch) {
        guard let mediaItem = match.mediaItems.first else { return }
        
        self.currentItem = mediaItem
        
        // create a new CoreData entry with all the metadata!
        let newItem = SStream(context: viewContext)
        
        newItem.timestamp = Date()
        
        if (locationController.loc.authorizationStatus != .authorizedWhenInUse) {
            // todo handle
            print("LOCATION NOT AUTHORIZED")
        }
        
        newItem.latitude = locationController.loc.lastSeen?.coordinate.latitude ?? 0
        newItem.longitude = locationController.loc.lastSeen?.coordinate.longitude ?? 0
        newItem.altitude = locationController.loc.lastSeen?.altitude ?? 0
        newItem.speed = locationController.loc.lastSeen?.speed ?? 0
        newItem.state = locationController.loc.currentPlacemark?.administrativeArea ?? ""
        newItem.city = locationController.loc.currentPlacemark?.locality ?? ""
        newItem.country = locationController.loc.currentPlacemark?.country ?? ""
        newItem.countryCode = locationController.loc.currentPlacemark?.isoCountryCode ?? ""
        
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
