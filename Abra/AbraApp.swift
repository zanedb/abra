//
//  AbraApp.swift
//  Abra
//

import SwiftUI

@main
struct abraApp: App {
    @ObservedObject var library = LibraryService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
        }
            .modelContainer(for: ShazamStream.self)
    }
}
