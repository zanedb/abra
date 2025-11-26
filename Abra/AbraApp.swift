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
        ValueTransformer.setValueTransformer(UIColorValueTransformer(), forName: NSValueTransformerName("UIColorValueTransformer"))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
//                .environment(\.database, database)
        }
        .modelContainer(for: [ShazamStream.self, Spot.self])
    }
}
