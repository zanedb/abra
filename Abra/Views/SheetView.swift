//
//  SheetView.swift
//  Abra
//

import SectionedQuery
import Sentry
import ShazamKit
import SwiftData
import SwiftUI

import struct SectionedQuery.SectionedResults

struct SheetView: View {
    @Environment(\.toastProvider) private var toast
    @Environment(\.openURL) private var openURL
    @Environment(SheetProvider.self) private var view
    @Environment(ShazamProvider.self) private var shazam
    @Environment(LocationProvider.self) private var location
    @Environment(LibraryProvider.self) private var library
    @Environment(MusicProvider.self) private var music
    @Environment(MotionProvider.self) private var motion

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
                || $0.note.localizedCaseInsensitiveContains(view.searchText)
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
    @State private var longPressHandled = false

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
                        SearchResults
                    }
                }
            }
            .abraSwipeActionsContainer()
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
        .fullScreenCover(isPresented: searchingPresentation) {
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
        .onChange(of: view.isPresented) { _, isPresented in
            if isPresented {
                view.collapseBottomSheet?()
            } else {
                view.expandBottomSheet?()
            }
        }
        .onChange(of: shazam.status) {
            if case .error(let error) = shazam.status {
                handleShazamAPIError(error)
            }
        }
        .onAppear {
            // If location was "allow once" request again
            if location.authorizationStatus == .notDetermined {
                location.requestPermission()
            }
            // We’ll need this soon
            location.requestLocation()
            // Request motion permission if never prompted (e.g. onboarded before this was added)
            if motion.isAvailable
                && motion.authorizationStatus == .notDetermined
            {
                motion.requestPermission()
            }
        }
    }

    private var searchingPresentation: Binding<Bool> {
        Binding(
            get: { view.isSearching },
            set: { isPresented in
                let wasPresented = view.isSearching
                view.isSearching = isPresented

                if wasPresented && !isPresented
                    && shazam.isMatching && !shazam.continuous
                {
                    shazam.stopMatching()
                }
            }
        )
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
                        if longPressHandled {
                            longPressHandled = false
                            return
                        }
                        Task {
                            if shazam.isMatching {
                                shazam.stopMatching()
                            } else {
                                await shazam.startMatching()
                            }
                        }
                    } label: {
                        Group {
                            if shazam.continuous {
                                Waveform(on: true, size: 2)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "waveform")
                                    .font(.headline)
                                    .symbolRenderingMode(.multicolor)
                                    .foregroundStyle(.white)
                            }
                        }
                        .matchedTransitionSource(
                            id: "ShazamButton",
                            in: animation
                        )
                    }
                    .buttonStyle(GlassProminentButtonStyle())
                    .accessibilityLabel("Shazam")
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            longPressHandled = true
                            Task {
                                shazam.continuous = true
                                await shazam.startMatching()
                            }
                        }
                    )
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
                Button(action: {
                    Task {
                        if shazam.isMatching {
                            shazam.stopMatching()
                        } else {
                            await shazam.startMatching()
                        }
                    }
                }) {
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
                        SongRow(stream: shazam)
                        .onTapGesture { view.show(shazam) }
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

    private var SearchResults: some View {
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
        case .persistenceFailed:
            toast.show(
                message: "Song recognized, but couldn't save it. Retrying…",
                type: .error,
                symbol: "externaldrive.badge.exclamationmark"
            )
        case .microphonePermissionDenied:
            toast.show(
                message: "Allow microphone access to recognize music",
                type: .error,
                symbol: "mic.slash"
            )
        case .audioSessionFailed:
            toast.show(
                message: "Couldn't start listening",
                type: .error,
                symbol: "mic.slash"
            )
        default:
            break
        }
    }

}

private extension View {
    @ViewBuilder
    func abraSwipeActionsContainer() -> some View {
        if #available(iOS 27, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
