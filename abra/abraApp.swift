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

    let persistenceController = PersistenceController.shared

    @ObservedObject var vm = ViewModel()
    @StateObject var location = Location()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // TODO: prompt first time users.. for now
                    // TODO: handle no location perms
                    location.requestPermission()
                }
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(vm)
                .onChange(of: scenePhase) { phase in
                    // MARK: on app close, save last active region to defaults, next launch opens there
                    if phase == .inactive {
                        UserDefaults.standard.set(vm.center.latitude, forKey: "LatCoord")
                        UserDefaults.standard.set(vm.center.longitude, forKey: "LongCoord")
                    }
                }
        }
    }
}
