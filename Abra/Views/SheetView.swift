//
//  SheetView.swift
//  Abra
//

import SectionedQuery
import Sentry
import ShazamKit
import SwiftData
import SwiftUI

struct SheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastProvider) private var toast
    @Environment(\.openURL) private var openURL
    @Environment(SheetProvider.self) private var view
    @Environment(ShazamProvider.self) private var shazam
    @Environment(LocationProvider.self) private var location
    @Environment(LibraryProvider.self) private var library
    @Environment(MusicProvider.self) private var music

    @SectionedQuery(
        \.timeGroupedString,
        sort: [SortDescriptor(\.timestamp, order: .reverse)]
    ) private var timeSectionedStreams: SectionedResults<String, ShazamStream>

    @Query(sort: \ShazamStream.timestamp, order: .reverse) private
        var allShazams: [ShazamStream]
    @Query(sort: \Spot.updatedAt, order: .reverse) private var allSpots: [Spot]

    var shazams: [ShazamStream] {
        guard view.searchText.isEmpty == false else { return allShazams }

        return allShazams.filter {
            $0.title.localizedCaseInsensitiveContains(view.searchText)
                || $0.artist.localizedCaseInsensitiveContains(view.searchText)
                || $0.cityState.localizedCaseInsensitiveContains(
                    view.searchText
                )
        }
    }

    var spots: [Spot] {
        guard view.searchText.isEmpty == false else { return allSpots }

        return allSpots.filter {
            $0.name.localizedCaseInsensitiveContains(view.searchText)
                || $0.description.localizedCaseInsensitiveContains(
                    view.searchText
                )
        }
    }

    @Namespace var animation

    @State private var searchHidden: Bool = false
    @State private var searchFocused: Bool = false
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if view.searchText.isEmpty {
                    SpotsList()
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    SongsList

                    if spots.isEmpty && shazams.isEmpty {
                        Text("Let‘s Discover")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 72)
                        Text("Tap the Shazam icon to start recognizing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if spots.isEmpty && shazams.isEmpty {
                        ContentUnavailableView.search(text: view.searchText)
                            .padding()
                    } else {
                        searchResults
                    }
                }
            }
            .toolbar {
                ToolbarItems
            }
            .backportSearchable(
                text: view.searchTextBinding,
                isPresented: $searchFocused,
                placement: .toolbar,
                prompt: "Shazams, Spots, Places, and More"
            )
        }
        .fullScreenCover(isPresented: shazam.isMatchingBinding) {
            Searching(namespace: animation)
        }
        .sheet(isPresented: view.isPresentedBinding) {
            switch view.now {
            case .stream(let stream):
                song(stream)
            case .spot(let item):
                spot(item)
            case .none:
                EmptyView()
            }
        }
        .onChange(of: shazam.status) {
            if case .matched(let song) = shazam.status {
                createShazamStream(song)
            }

            if case .error(let error) = shazam.status {
                handleShazamAPIError(error)
            }
        }
        .onChange(of: location.currentPlacemark) {
            // Save location if it wasn't initially ready on latest stream
            updateLocationlessStreams()
        }
        .onAppear {
            // If location was "allow once" request again
            if location.authorizationStatus == .notDetermined {
                location.requestPermission()
            }
            // We‘ll need this soon
            location.requestLocation()
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }

    @ToolbarContentBuilder
    private var ToolbarItems: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .principal) {
                TextField(
                    "Shazams, Spots, Places, and More",
                    text: view.searchTextBinding
                )
                .fontWeight(.medium)
                .padding(.horizontal)
                .padding(.trailing, 12)
                .padding(.vertical, 11)
                .clipShape(ConcentricRectangle())
                .glassEffect()
            }

            ToolbarItem(placement: .primaryAction) {
                if view.searchText.isEmpty {
                    Button {
                        Task {
                            await shazam.startMatching()
                        }
                    } label: {
                        Image(systemName: "shazam.logo")
                            .font(.headline)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(.white)
                            .matchedTransitionSource(
                                id: "ShazamButton",
                                in: animation
                            )
                    }
                    .buttonStyle(GlassProminentButtonStyle())
                    .accessibilityLabel("Shazam")
                } else {
                    Button {
                        view.searchText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .contentTransition(.symbolEffect(.replace))
                            .accessibilityLabel("Dismiss Search")
                            .matchedTransitionSource(
                                id: "ShazamButton",
                                in: animation
                            )
                    }
                    .accessibilityLabel("Dismiss Search")
                }
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Text("Abra")
                    .font(.title2.weight(.medium))
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await shazam.startMatching() } }) {
                    Image(systemName: "shazam.logo.fill")
                        .fontWeight(.medium)
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(.blue)
                        .matchedTransitionSource(
                            id: "ShazamButton",
                            in: animation
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var SongsList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(timeSectionedStreams) { section in
                Section {
                    ForEach(section) { shazam in
                        Button(action: { view.show(shazam) }) {
                            SongRow(stream: shazam)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, shazam == section.last ? 12 : 0)

                        if shazam != section.last {
                            Divider()
                                .padding(.leading, 125)
                        }
                    }
                } header: {
                    Text("\(section.id)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.weight(.medium))
                        .textCase(.uppercase)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var searchResults: some View {
        LazyVStack(alignment: .leading) {
            Section {
                ForEach(spots, id: \.id) { spot in
                    Button(action: { view.show(spot) }) {
                        SpotRow(spot: spot)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 60)
                }
            }

            Section {
                ForEach(shazams, id: \.id) { stream in
                    SongRowMini(
                        stream: stream,
                        onTapGesture: {
                            view.show(stream)
                        }
                    )
                    .padding(.vertical, 4)
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .padding(.horizontal)
    }

    private func song(_ stream: ShazamStream) -> some View {
        SongView(stream: stream)
            .presentationDetents([.fraction(0.50), .large])
            .presentationInspector()
            .edgesIgnoringSafeArea(.bottom)
            .prefersEdgeAttachedInCompactHeight()
    }

    private func spot(_ spot: Spot) -> some View {
        SpotView(spot: spot)
            .presentationDetents([.fraction(0.50), .large])
            .presentationInspector()
            .prefersEdgeAttachedInCompactHeight()
    }

    private func createShazamStream(_ mediaItem: SHMediaItem) {
        // Create and show ShazamStream
        let stream = ShazamStream(
            mediaItem: mediaItem,
            location: location.currentLocation,
            placemark: location.currentPlacemark
        )
        modelContext.insert(stream)
        try? modelContext.save()
        view.show(stream)
        hapticTrigger.toggle()

        // If Spot exists with similar latitude/longitude, set it automatically
        Task {
            stream.spotIt(context: modelContext)
        }
    }

    private func handleShazamAPIError(_ error: ShazamError) {
        switch error {
        case .noMatch:
            toast.show(
                message: "No match found",
                type: .info,
                symbol: "shazam.logo.fill"
            )
        case .matchFailed(let error):
            guard let errorCode = extractShazamErrorCode(from: error),
                errorCode != "(null)"
            else { return }
            SentrySDK.capture(error: error)
            toast.show(
                message: errorCode,
                type: .error,
                symbol: "shazam.logo.fill"
            )
        default:
            break
        }
    }

    // Maybe we get a grip on location first, save that, and then make a background task to update Placemarks from location?
    // Should probably do anyway..
    private func updateLocationlessStreams() {
        guard let currentLoc = location.currentLocation else { return }

        // Find locationless streams within the past hour
        let locationless = allShazams.filter {
            $0.latitude == -1 && $0.longitude == -1
                && $0.timestamp > Date().addingTimeInterval(-60 * 60)
        }

        print("Found \(locationless.count) locationless streams")

        for stream in locationless {
            stream.updateLocation(
                currentLoc,
                placemark: location.currentPlacemark
            )
            stream.spotIt(context: modelContext)
            if view.now == .stream(stream) {
                view.show(stream)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
