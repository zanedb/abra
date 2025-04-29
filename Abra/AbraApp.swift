//
//  AbraApp.swift
//  Abra
//

import SwiftUI

@main
struct abraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
            .modelContainer(for: ShazamStream.self)
    }
}
