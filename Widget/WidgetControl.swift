//
//  WidgetControl.swift
//  Widget
//

import AppIntents
import SwiftUI
import WidgetKit

/// Starts a Shazam recording session from Control Center
struct Control: ControlWidget {
    let kind: String = "app.zane.abra.widget"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: StartShazamSessionIntent()) {
                Label("Recognize Music", systemImage: "shazam.logo")
            }
        }
            .displayName("Recognize Music")
            .description("Use Shazam to recognize and add currently playing music")
    }
}
