//
//  AbraApp.swift
//  Abra
//

import SwiftUI

@main
struct abraApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var vm = ViewModel()
    @ObservedObject var library = LibraryService()
    @StateObject var location = Location()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // TODO: prompt first time users.. for now
                    // TODO: handle no location perms
                    location.requestPermission()
                }
                .environmentObject(vm)
                .environmentObject(library)
        }
        .modelContainer(for: ShazamStream.self)
    }
}
