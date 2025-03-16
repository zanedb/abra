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

    var dismissIntent: DismissLiveActivityIntent {
        DismissLiveActivityIntent()
    }
}

/// Ends the Shazam recording session and the Live Activity
struct DismissLiveActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Dismiss Live Activity"
    static var description: IntentDescription = IntentDescription("Stops the Shazam recording session")
    static var openAppWhenRun: Bool = true // Also included alongside @MainActor
    
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
