//
//  AbraApp.swift
//  Abra
//

import Sentry
import SwiftData
import SwiftUI

@main
struct abraApp: App {
    private let benchmarkContainer: ModelContainer?

    init() {
        benchmarkContainer = MapBenchmarkConfiguration.makeContainerIfRequested()

        if benchmarkContainer == nil {
            SentrySDK.start { options in
                options.dsn =
                    "https://d336ddac8a50dbb29910b3384c913606@o4504745853321216.ingest.us.sentry.io/4509637227773952"
                options.debug = false
                options.sendDefaultPii = true
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let benchmarkContainer {
                ContentView()
                    .modelContainer(benchmarkContainer)
            } else {
                ContentView()
                    .modelContainer(for: [ShazamStream.self, Spot.self])
            }
        }
    }
}
