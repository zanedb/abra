//
//  ActivityAttributes.swift
//  Abra
//
//

import ActivityKit
import AppIntents

///  Defines shared attributes between the Widget and Abra bundles, used in the ShazamProvider and Widget components.
struct WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var takingTooLong: Bool
        var continuous: Bool = false
        var matchCount: Int = 0
        var locationName: String? = nil
        var matchedTitle: String? = nil
        var matchedArtist: String? = nil

        // Activities can survive an app update with the previous payload shape.
        // Property defaults alone don't supply missing keys during Codable decoding.
        private enum CodingKeys: String, CodingKey {
            case takingTooLong, continuous, matchCount, locationName, matchedTitle, matchedArtist
        }

        init(takingTooLong: Bool, continuous: Bool = false, matchCount: Int = 0,
             locationName: String? = nil, matchedTitle: String? = nil, matchedArtist: String? = nil) {
            self.takingTooLong = takingTooLong
            self.continuous = continuous
            self.matchCount = matchCount
            self.locationName = locationName
            self.matchedTitle = matchedTitle
            self.matchedArtist = matchedArtist
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            takingTooLong = try values.decodeIfPresent(Bool.self, forKey: .takingTooLong) ?? false
            continuous = try values.decodeIfPresent(Bool.self, forKey: .continuous) ?? false
            matchCount = try values.decodeIfPresent(Int.self, forKey: .matchCount) ?? 0
            locationName = try values.decodeIfPresent(String.self, forKey: .locationName)
            matchedTitle = try values.decodeIfPresent(String.self, forKey: .matchedTitle)
            matchedArtist = try values.decodeIfPresent(String.self, forKey: .matchedArtist)
        }
    }
}

/// Starts the Shazam recording session and the Live Activity
struct StartShazamSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Recognize Music"
    static let description: IntentDescription = IntentDescription("Starts recognizing the current song using Shazam")
    static let openAppWhenRun: Bool = true // Also included alongside @MainActor

    @Parameter(title: "Continuous", default: false)
    var continuous: Bool
    
    init() {
        continuous = false
    }

    init(continuous: Bool) {
        self.continuous = continuous
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Tell ShazamProvider to start the recording session
        NotificationCenter.default.post(
            name: Notification.Name("StartShazamRecordingIntent"),
            object: nil,
            userInfo: ["continuous": continuous]
        )
        
        return .result()
    }
}

/// Ends the Shazam recording session and the Live Activity
struct EndShazamSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Recognizing Music"
    static let description: IntentDescription = IntentDescription("Stops the current Shazam session")
    
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
        // Tell ShazamProvider to end the recording session
        NotificationCenter.default.post(
            name: Notification.Name("StopShazamRecordingIntent"),
            object: nil,
            userInfo: ["activityID": activityID]
        )
        
        return .result()
    }
}
