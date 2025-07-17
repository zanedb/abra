//
//  LocationPicker.swift
//  Abra
//

import SwiftData
import SwiftUI

struct LocationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationProvider.self) private var locationProvider
    
    @Binding var lat: Double
    @Binding var lng: Double
    
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
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Places")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .onChange(of: searchText) {
                locationProvider.update(queryFragment: searchText)
            }
            .onAppear {
                locationProvider.requestLocation()
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
        // Update lat/lng from placemark
        Task {
            if let singleLocation = try? await locationProvider.search(with: "\(completion.title) \(completion.subTitle)").first {
                lat = singleLocation.location.latitude
                lng = singleLocation.location.longitude
            }
        }
        dismiss()
    }
    
    private func setCurrentLocation() {
        // Get user's location, update lat/lng
        Task {
            if let currentLocation = locationProvider.currentLocation {
                lat = currentLocation.coordinate.latitude
                lng = currentLocation.coordinate.longitude
            }
        }
        dismiss()
    }
}

#Preview {
    @Previewable @State var stream: ShazamStream = .preview
    
    VStack {}
        .popover(isPresented: .constant(true)) {
            LocationPicker(lat: $stream.latitude, lng: $stream.longitude)
                .presentationDetents([.fraction(0.999)])
                .presentationBackground(.thickMaterial)
                .environment(LocationProvider())
                .modelContainer(PreviewSampleData.container)
        }
}
