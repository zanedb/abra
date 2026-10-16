//
//  LocationPicker.swift
//  Abra
//

import MapKit
import SwiftData
import SwiftUI

struct LocationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationProvider.self) private var locationProvider

    var stream: ShazamStream

    @State private var searchText = ""
    @State private var isUpdating = false
    @State private var updateTask: Task<Void, Never>?
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Button(action: setCurrentLocation) {
                        currentLocationRow
                    }

                    Section("Recents") {
                        //                        ForEach(placemarks, id: \.id) { placemark in
                        //                            Button(action: { setLocation(placemark) }) {
                        //                                PlacemarkRow(placemark)
                        //                            }
                        //                        }
                    }
                } else {
                    ForEach(locationProvider.completions) { completion in
                        Button(action: { setLocation(completion) }) {
                            LocationRow(completion)
                        }
                    }

                    if locationProvider.completions.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.inset)
            .disabled(isUpdating)
            .overlay {
                if isUpdating {
                    ProgressView("Updating location…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
            }
            .navigationTitle("Adjust Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Find Places"
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    DismissButton()
                }
            }
            .onAppear { locationProvider.update(queryFragment: "") }
            .onChange(of: searchText) {
                locationProvider.update(queryFragment: searchText)
            }
            .onDisappear { updateTask?.cancel() }
            .alert("Couldn't Update Location", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var currentLocationRow: some View {
        HStack {
            Image(systemName: "location.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
                .padding(.trailing, 4)

            VStack(alignment: .leading) {
                Text("Current Location")
                    .font(.headline)
            }
        }
    }

    private func LocationRow(_ completion: SearchCompletions) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(completion.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(completion.subTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func setLocation(_ completion: SearchCompletions) {
        updateLocation {
            let mapItem = try await locationProvider.search(for: completion)
            try Task.checkCancellation()
            try stream.saveLocationEdit { song, context in
                song.setLocationFromPicker(mapItem, context: context)
            }
        }
    }

    private func setCurrentLocation() {
        updateLocation {
            let location = try await locationProvider.locationForPicker()
            var placemark = locationProvider.placemark(for: location)
            if placemark == nil {
                // Failure to find a place name must not discard usable coordinates.
                placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            }
            try Task.checkCancellation()
            try stream.saveLocationEdit { song, context in
                song.setLocationFromPicker(location, placemark: placemark,
                                           context: context, allowSpot: !locationProvider.hasReducedAccuracy)
            }
        }
    }

    private func updateLocation(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !isUpdating else { return }
        isUpdating = true
        updateTask = Task { @MainActor in
            defer { isUpdating = false }
            do {
                try await operation()
                try Task.checkCancellation()
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

}

#Preview {
    @Previewable @State var stream: ShazamStream = .preview

    VStack {}
        .popover(isPresented: .constant(true)) {
            LocationPicker(stream: stream)
                .presentationDetents([.fraction(0.999)])
                .environment(LocationProvider())
                .modelContainer(PreviewSampleData.container)
        }
}
