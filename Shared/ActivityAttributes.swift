//
//  ActivityAttributes.swift
//  Abra
//
//  Defines shared attributes between the Widget and Abra bundles, used in the ViewModel and Widget components.
//

import ActivityKit

struct WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var takingTooLong: Bool
    }

    // Fixed non-changing properties here
}
