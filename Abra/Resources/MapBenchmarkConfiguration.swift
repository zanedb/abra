//
//  MapBenchmarkConfiguration.swift
//  Abra
//

import MapKit
import SwiftData
import UIKit

/// Creates a deterministic, in-memory data store when `-MapBenchmarkCount`
/// is supplied as a launch argument. Normal app launches are unaffected.
enum MapBenchmarkConfiguration {
    private static let countArgument = "-MapBenchmarkCount"
    private static let distributionArgument = "-MapBenchmarkDistribution"

    enum Distribution: String {
        case dense
        case spread
    }

    static let requestedCount: Int? = {
        guard let value = argumentValue(after: countArgument),
              let count = Int(value),
              (0...20_000).contains(count)
        else {
            return nil
        }
        return count
    }()

    static let distribution: Distribution = {
        guard let value = argumentValue(after: distributionArgument) else {
            return .dense
        }
        return Distribution(rawValue: value) ?? .dense
    }()

    static var isEnabled: Bool {
        requestedCount != nil
    }

    static var mapRegion: MKCoordinateRegion? {
        guard isEnabled else { return nil }

        let span: MKCoordinateSpan = switch distribution {
        case .dense:
            MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        case .spread:
            MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 120)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: 37.7749,
                longitude: -122.4194
            ),
            span: span
        )
    }

    @MainActor
    static func makeContainerIfRequested() -> ModelContainer? {
        guard let requestedCount else { return nil }

        do {
            let schema = Schema([ShazamStream.self, Spot.self])
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            let context = container.mainContext
            context.autosaveEnabled = false

            let gridWidth = max(1, Int(ceil(sqrt(Double(requestedCount)))))
            let artworkURL = URL(string: "https://zane.link/abra-unavailable")!
            let spotColors: [UIColor] = [
                .systemIndigo,
                .systemBlue,
                .systemGreen,
                .systemOrange,
                .systemPink,
            ]

            for index in 0..<requestedCount {
                let coordinate = coordinate(for: index, gridWidth: gridWidth)

                if index.isMultiple(of: 10) {
                    let spot = Spot(
                        name: "Benchmark Spot \(index)",
                        symbol: "mappin.and.ellipse",
                        color: spotColors[(index / 10) % spotColors.count],
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    context.insert(spot)
                } else {
                    let stream = ShazamStream(
                        title: "Benchmark Stream \(index)",
                        artist: "Benchmark Artist",
                        artworkURL: artworkURL,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    context.insert(stream)
                }
            }

            try context.save()
            return container
        } catch {
            fatalError("Unable to create map benchmark data: \(error)")
        }
    }

    private static func argumentValue(after argument: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: argument),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func coordinate(
        for index: Int,
        gridWidth: Int
    ) -> CLLocationCoordinate2D {
        let row = index / gridWidth
        let column = index % gridWidth
        let centeredRow = Double(row) - Double(gridWidth - 1) / 2
        let centeredColumn = Double(column) - Double(gridWidth - 1) / 2

        let spacing: Double = switch distribution {
        case .dense: 0.0004
        case .spread: 0.35
        }

        return CLLocationCoordinate2D(
            latitude: 37.7749 + centeredRow * spacing,
            longitude: -122.4194 + centeredColumn * spacing
        )
    }
}
