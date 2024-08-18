//
//  PreviewSampleData.swift
//  abra
//
//  The preview sample data actor which provides an in-memory model container.
//
//  Created by Zane on 9/24/23.
//

import SwiftData
import SwiftUI

/**
 Preview sample data.
 */
actor PreviewSampleData {

    @MainActor
    static var container: ModelContainer = {
        return try! inMemoryContainer()
    }()

    static var inMemoryContainer: () throws -> ModelContainer = {
        let schema = Schema([ShazamStream.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let sampleData: [any PersistentModel] = [
            ShazamStream.preview
        ]
        Task { @MainActor in
            sampleData.forEach {
                container.mainContext.insert($0)
            }
        }
        return container
    }
}
