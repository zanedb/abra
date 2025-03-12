//
//  ActivityAttributes.swift
//  abra
//
//  Created by Zane on 3/11/25.
//

import ActivityKit

struct WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var takingTooLong: Bool
    }

    // Fixed non-changing properties here
}
