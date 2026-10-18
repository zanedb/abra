import AppIntents
import SwiftUI
import WidgetKit

struct ContinuousControl: ControlWidget {
    let kind = "app.zane.abra.widget.continuous"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: StartShazamSessionIntent(continuous: true)) {
                Label("Recognize Music (Continuous)", image: "abra.logo")
            }
        }
        .displayName("Recognize Music (Continuous)")
        .description("Use Shazam to recognize currently playing music in Continuous mode.")
    }
}
