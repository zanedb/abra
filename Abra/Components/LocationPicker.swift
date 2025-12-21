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
            .onChange(of: searchText) {
                locationProvider.update(queryFragment: searchText)
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
        // Attempt to fetch placemark and location from search
        Task {
            if let singleLocation = try? await locationProvider.search(
                with: "\(completion.title) \(completion.subTitle)"
            ).first {
                let clLocation = CLLocation(
                    latitude: singleLocation.location.latitude,
                    longitude: singleLocation.location.longitude
                )
                let geocoder = CLGeocoder()

                geocoder.reverseGeocodeLocation(clLocation) {
                    (placemarks, error) in
                    if error == nil {
                        if let firstPlacemark = placemarks?.first {
                            stream.updateLocation(
                                clLocation,
                                placemark: firstPlacemark
                            )
                        }
                    } else {
                        print(
                            "Couldn't fetch placemark, updating location without"
                        )
                        stream.updateLocation(
                            clLocation
                        )
                    }
                }
            }
        }
        dismiss()
    }

    private func setCurrentLocation() {
        // Get user’s current loc + placemark, use it to update
        Task {
            if let currentLocation = locationProvider.currentLocation,
                let currentPlacemark = locationProvider.currentPlacemark
            {
                stream.updateLocation(
                    currentLocation,
                    placemark: currentPlacemark
                )
                dismiss()
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
