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
                .onChange(of: scenePhase) {
                    // If app is minimized and no session is active, stop recording
                    if (scenePhase == .inactive && !vm.isActivityRunning) {
                        vm.stopRecording()
                    }
                }
        }
            .modelContainer(for: ShazamStream.self)
    }
}
