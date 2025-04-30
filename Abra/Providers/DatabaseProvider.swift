//
//  DatabaseProvider.swift
//  Abra
//
//  Inspired by https://www.massicotte.org/model-actor
//

import SwiftData
import SwiftUI

@MainActor
struct DatabaseProvider {
    @ModelActor
    actor Background {
        static nonisolated func create(container: ModelContainer) async -> Background {
            Background(modelContainer: container)
        }
    }
    
    public let mainContext: ModelContext
    private let task: Task<Background, Never>
    
    init(container: ModelContainer) {
        self.mainContext = container.mainContext
        self.task = Task { await Background.create(container: container) }
    }
    
    public var background: Background {
        get async { await task.value }
    }
}

extension EnvironmentValues {
    @Entry var database: DatabaseProvider?
}

// This is stupid.
extension ModelContext {
    func fetchShazamStreams(fromIdentifiers identifiers: [PersistentIdentifier]) -> [ShazamStream] {
        var shazamStreams: [ShazamStream] = []
        
        for identifier in identifiers {
            if let shazamStream = model(for: identifier) as? ShazamStream {
                shazamStreams.append(shazamStream)
            }
        }
        
        return shazamStreams
    }
}
