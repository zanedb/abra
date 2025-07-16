//
//  SpotSelector.swift
//  Abra
//

import SwiftData
import SwiftUI

struct SpotSelector: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selection: Spot?
    var newSpotCallback: () -> Void
    
    @State private var searchText = ""
    
    @Query(sort: \Spot.updatedAt, order: .reverse)
    private var spots: [Spot]
    
    private var searchResults: [Spot] {
        spots.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    if selection != nil {
                        Button(action: removeSpot) {
                            noSpotRow
                        }
                    } else {
                        Button(action: newSpotCallback) {
                            newSpotRow
                        }
                    }
                    
                    Section("Spots") {
                        ForEach(spots, id: \.id) { spot in
                            Button(action: { setSpot(spot) }) {
                                SpotRow(spot)
                            }
                        }
                    }
                } else {
                    ForEach(searchResults, id: \.id) { spot in
                        Button(action: { setSpot(spot) }) {
                            SpotRow(spot)
                        }
                    }
                    
                    if searchResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle("Select Spot")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Spots")
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
        }
    }
    
    private var newSpotRow: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
                .padding(.trailing, 4)
            
            VStack(alignment: .leading) {
                Text("New Spot")
                    .font(.headline)
            }
        }
    }
    
    private var noSpotRow: some View {
        HStack {
            Image(systemName: "mappin.slash.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(.red)
                .symbolRenderingMode(.hierarchical)
                .padding(.trailing, 4)
            
            VStack(alignment: .leading) {
                Text("No Spot")
                    .font(.headline)
            }
        }
    }
    
    private func SpotRow(_ spot: Spot) -> some View {
        HStack {
            SpotIcon(symbol: spot.symbol, color: Color(spot.color), size: 40, renderingMode: .hierarchical)
                .padding(.trailing, 4)
            
            VStack(alignment: .leading) {
                Text(spot.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(spot.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private func setSpot(_ spot: Spot) {
        selection = spot
        dismiss()
    }
    
    private func removeSpot() {
        selection = nil
        dismiss()
    }
}

#Preview {
    @Previewable @State var spot: Spot?
    
    VStack {}
        .popover(isPresented: .constant(true)) {
            SpotSelector(selection: $spot, newSpotCallback: {})
                .presentationDetents([.fraction(0.999)])
                .presentationBackground(.thickMaterial)
                .modelContainer(PreviewSampleData.container)
        }
}
