//
//  AbraApp.swift
//  Abra
//

import SwiftData
import SwiftUI

@main
struct abraApp: App {
//    let database: Database
//    
//    init() {
//        let schema = Schema([ShazamStream.self, Place.self])
//        let modelConfiguration = ModelConfiguration(schema: schema)
//        
//        do {
//            let container = try ModelContainer(for: schema, configurations: modelConfiguration)
//            database = Database(container: container)
//        } catch {
//            fatalError("Failed to create modelContainer: \(error.localizedDescription)")
//        }
//    }

    var body: some Scene {
        WindowGroup {
            ContentView()
//                .environment(\.database, database)
        }
            .modelContainer(for: ShazamStream.self)
    }
}
