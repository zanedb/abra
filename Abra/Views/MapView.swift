//
//  MapView.swift
//  Abra
//

import SwiftData
import SwiftUI

/// Owns the SwiftUI data dependencies for the MapKit-backed map.
struct MapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastProvider) private var toast
    @Environment(SheetProvider.self) private var sheetProvider
    @Environment(ShazamProvider.self) private var shazam
    @Environment(LocationProvider.self) private var location
    @Environment(LibraryProvider.self) private var library
    @Environment(MotionProvider.self) private var motion
    @Environment(MusicProvider.self) private var music

    @Query(
        filter: #Predicate<ShazamStream> { $0.spot == nil },
        sort: \ShazamStream.timestamp,
        order: .reverse
    )
    private var shazams: [ShazamStream]

    @Query(sort: \Spot.updatedAt, order: .reverse)
    private var spots: [Spot]

    var body: some View {
        MapViewControllerRepresentable(
            shazams: shazams,
            spots: spots,
            modelContext: modelContext,
            toast: toast,
            sheetProvider: sheetProvider,
            shazam: shazam,
            location: location,
            library: library,
            motion: motion,
            music: music
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
