//
//  ActivityAttributes.swift
//  Abra
//
//

import ActivityKit
import AppIntents

///  Defines shared attributes between the Widget and Abra bundles, used in the ViewModel and Widget components.
struct WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var takingTooLong: Bool
    }
}

/// Starts the Shazam recording session and the Live Activity
struct StartShazamSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Recognize Music"
    static let description: IntentDescription = IntentDescription("Starts recognizing the current song using Shazam")
    static let openAppWhenRun: Bool = true // Also included alongside @MainActor
    
    init() {}
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Tell ViewModel to start the recording session
        NotificationCenter.default.post(
            name: Notification.Name("StartShazamRecordingIntent"),
            object: nil
        )
        
        return .result()
    }
}

/// Ends the Shazam recording session and the Live Activity
struct EndShazamSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Recognizing Music"
    static let description: IntentDescription = IntentDescription("Stops the current Shazam session")
    static let openAppWhenRun: Bool = true // Also included alongside @MainActor
    
    @Parameter(title: "Activity ID")
    var activityID: String
    
    init() {
        self.activityID = ""
    }
    
    init(activityID: String) {
        self.activityID = activityID
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Tell ViewModel to end the recording session
        NotificationCenter.default.post(
            name: Notification.Name("StopShazamRecordingIntent"),
            object: nil,
            userInfo: ["activityID": activityID]
        )
        
        return .result()
    }
}
