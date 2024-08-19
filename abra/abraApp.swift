//
//  abraApp.swift
//  abra
//
//  Created by Zane on 6/5/23.
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
                .onChange(of: scenePhase) {
                    // MARK: on app close, stop shazam session if active
                    if scenePhase == .inactive {
                        vm.stopRecording()
                    }
                }
        }
        .modelContainer(for: ShazamStream.self)
    }
}
