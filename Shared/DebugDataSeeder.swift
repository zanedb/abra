//
//  DebugDataSeeder.swift
//  Abra
//
//  Debug-only data seeding for testing CloudKit sync
//

import Foundation
import SwiftData
import SwiftUI

#if DEBUG
    @MainActor
    class DebugDataSeeder: ObservableObject {

        static let sampleSongs = [
            (
                "Blinding Lights", "The Weeknd",
                "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/b8/29/28/b8292815-18ba-4f1d-b7bb-8a7b8b0b2b2b/20UMGIM01616.rgb.jpg/400x400cc.jpg"
            ),
            (
                "Good 4 U", "Olivia Rodrigo",
                "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a8/12/67/a8126789-c9f2-4c8a-9f0c-1a2b3c4d5e6f/21UMAR00123.rgb.jpg/400x400cc.jpg"
            ),
            (
                "Stay", "The Kid LAROI, Justin Bieber",
                "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/c1/23/45/c1234567-89ab-cdef-0123-456789abcdef/21UMGIM12345.rgb.jpg/400x400cc.jpg"
            ),
            (
                "Heat Waves", "Glass Animals",
                "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/d2/34/56/d2345678-9abc-def0-1234-56789abcdef0/20UNIM56789.rgb.jpg/400x400cc.jpg"
            ),
            (
                "Levitating", "Dua Lipa",
                "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/e3/45/67/e3456789-abcd-ef01-2345-6789abcdef01/20WWIM67890.rgb.jpg/400x400cc.jpg"
            ),
            (
                "Peaches", "Justin Bieber ft. Daniel Caesar, Giveon",
                "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/f4/56/78/f4567890-bcde-f012-3456-789abcdef012/21UMGIM78901.rgb.jpg/400x400cc.jpg"
            ),
            (
                "Bad Habits", "Ed Sheeran",
                "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/05/67/89/05678901-cdef-0123-4567-89abcdef0123/21ATIM89012.rgb.jpg/400x400cc.jpg"
            ),
            (
                "Industry Baby", "Lil Nas X, Jack Harlow",
                "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/16/78/90/16789012-def0-1234-5678-9abcdef01234/21COLIM90123.rgb.jpg/400x400cc.jpg"
            ),
        ]

        static let sampleLocations = [
            (
                "San Francisco", 37.7749, -122.4194, "California",
                "United States"
            ),
            ("New York", 40.7128, -74.0060, "New York", "United States"),
            ("Los Angeles", 34.0522, -118.2437, "California", "United States"),
            ("Chicago", 41.8781, -87.6298, "Illinois", "United States"),
            ("Miami", 25.7617, -80.1918, "Florida", "United States"),
            ("Seattle", 47.6062, -122.3321, "Washington", "United States"),
            ("Austin", 30.2672, -97.7431, "Texas", "United States"),
            ("Denver", 39.7392, -104.9903, "Colorado", "United States"),
        ]

        static let sampleSpots = [
            (
                "The Fillmore", "music.note", UIColor.systemPurple, 37.7841,
                -122.4332
            ),
            (
                "Madison Square Garden", "building.2", UIColor.systemBlue,
                40.7505, -73.9934
            ),
            (
                "Hollywood Bowl", "theatermasks", UIColor.systemRed, 34.1122,
                -118.3390
            ),
            (
                "Red Rocks", "mountain.2", UIColor.systemOrange, 39.6654,
                -105.2057
            ),
            ("Coachella", "sun.max", UIColor.systemYellow, 33.6803, -116.2378),
            ("SXSW", "guitars", UIColor.systemGreen, 30.2672, -97.7431),
        ]

        func seedSampleData(context: ModelContext, count: Int = 20) {
            // Clear existing data first
            clearAllData(context: context)

            // Create spots first
            let spots = createSampleSpots(context: context)

            // Create ShazamStreams
            createSampleShazamStreams(
                context: context,
                count: count,
                spots: spots
            )

            // Save context
            try? context.save()
        }

        func clearAllData(context: ModelContext) {
            // Delete all ShazamStreams
            let streamDescriptor = FetchDescriptor<ShazamStream>()
            if let streams = try? context.fetch(streamDescriptor) {
                streams.forEach { context.delete($0) }
            }

            // Delete all Spots
            let spotDescriptor = FetchDescriptor<Spot>()
            if let spots = try? context.fetch(spotDescriptor) {
                spots.forEach { context.delete($0) }
            }

            try? context.save()
        }

        private func createSampleSpots(context: ModelContext) -> [Spot] {
            let spots = Self.sampleSpots.map {
                (name, symbol, color, lat, lon) in
                let spot = Spot(
                    name: name,
                    symbol: symbol,
                    color: color,
                    latitude: lat,
                    longitude: lon
                )
                context.insert(spot)
                return spot
            }
            return spots
        }

        private func createSampleShazamStreams(
            context: ModelContext,
            count: Int,
            spots: [Spot]
        ) {
            for i in 0..<count {
                let songIndex = i % Self.sampleSongs.count
                let locationIndex = i % Self.sampleLocations.count

                let (title, artist, artworkURLString) = Self.sampleSongs[
                    songIndex
                ]
                let (city, lat, lon, state, country) = Self.sampleLocations[
                    locationIndex
                ]

                // Create ShazamStream with sample data
                let stream = ShazamStream(
                    title: title,
                    artist: artist,
                    isExplicit: Bool.random(),
                    artworkURL: URL(string: artworkURLString) ?? URL(
                        string: "https://zane.link/abra-unavailable"
                    )!,
                    latitude: lat + Double.random(in: -0.01...0.01),  // Add some variance
                    longitude: lon + Double.random(in: -0.01...0.01),
                    appleMusicID: "sample_\(i)",
                    appleMusicURL: URL(
                        string: "https://music.apple.com/sample/\(i)"
                    )
                )

                // Set location data
                stream.city = city
                stream.state = state
                stream.country = country
                stream.countryCode = country == "United States" ? "US" : "XX"

                // Randomly assign to spots (some streams won't have spots)
                if Bool.random() && !spots.isEmpty {
                    let randomSpot = spots.randomElement()!
                    stream.spot = randomSpot
                    // Move stream location closer to spot
                    stream.latitude =
                        randomSpot.latitude + Double.random(in: -0.001...0.001)
                    stream.longitude =
                        randomSpot.longitude + Double.random(in: -0.001...0.001)
                }

                // Set random timestamp in the past month
                stream.timestamp = Date().addingTimeInterval(
                    -TimeInterval.random(in: 0...2_592_000)
                )  // 30 days

                context.insert(stream)
            }
        }
    }

    // MARK: - Debug UI Components

    struct DebugDataSeedingView: View {
        @Environment(\.modelContext) private var modelContext
        @StateObject private var seeder = DebugDataSeeder()
        @State private var isSeeding = false
        @State private var seedCount = 20

        var body: some View {
            VStack(spacing: 20) {
                Text("🛠️ Debug Data Seeding")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sample Count:")
                        Spacer()
                        Stepper(value: $seedCount, in: 1...100) {
                            Text("\(seedCount)")
                        }
                    }

                    Button(action: seedData) {
                        HStack {
                            if isSeeding {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSeeding ? "Seeding..." : "Seed Sample Data")
                        }
                    }
                    .disabled(isSeeding)
                    .buttonStyle(.borderedProminent)

                    Button(action: clearData) {
                        Text("Clear All Data")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .disabled(isSeeding)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Text(
                    "⚠️ This will replace all existing data with sample data for testing purposes."
                )
                .font(.caption)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
            }
            .padding()
        }

        private func seedData() {
            isSeeding = true
            Task {
                await MainActor.run {
                    seeder.seedSampleData(
                        context: modelContext,
                        count: seedCount
                    )
                    isSeeding = false
                }
            }
        }

        private func clearData() {
            seeder.clearAllData(context: modelContext)
        }
    }

    struct DebugControlsOverlay: View {
        @State private var showingDebugSheet = false

        var body: some View {
            Button(action: {
                showingDebugSheet = true
            }) {
                Image(systemName: "hammer.fill")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .sheet(isPresented: $showingDebugSheet) {
                NavigationView {
                    DebugDataSeedingView()
                        .navigationTitle("Debug Tools")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingDebugSheet = false
                                }
                            }
                        }
                }
            }
        }
    }

#else
    // Release build placeholder
    struct DebugControlsOverlay: View {
        var body: some View {
            EmptyView()
        }
    }
#endif
