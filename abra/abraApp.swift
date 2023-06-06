//
//  abraApp.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI

@main
struct abraApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
