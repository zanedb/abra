//
//  AbraApp.swift
//  Abra
//

import Sentry
import SwiftData
import SwiftUI

@main
struct abraApp: App {
    init() {
        ValueTransformer.setValueTransformer(
            UIColorValueTransformer(),
            forName: NSValueTransformerName("UIColorValueTransformer")
        )

        SentrySDK.start { options in
            options.dsn =
                "https://d336ddac8a50dbb29910b3384c913606@o4504745853321216.ingest.us.sentry.io/4509637227773952"
            options.debug = false
            options.sendDefaultPii = true
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ShazamStream.self, Spot.self])
    }
}
