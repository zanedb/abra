//
//  NewSpot.swift
//  Abra
//

import MapKit
import SwiftUI

struct NewSpot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var spotName: String = ""
    @State private var symbol: String = ""
    @State private var showingIconPicker: Bool = false
    
    private var notReady: Bool {
        spotName == "" || symbol == ""
    }
    
    var streams: [ShazamStream]
    
    var body: some View {
        NavigationStack {
            VStack {
                Divider()
                VStack {
                    HStack {
                        Button(action: { showingIconPicker.toggle() }) {
                            Image(systemName: symbol == "" ? "plus.circle.fill" : symbol)
                                .shadow(radius: 3, x: 0, y: 0)
                                .font(.system(size: symbol == "" ? 24 : 28))
                                .frame(width: 80, height: 80)
                                .foregroundColor(.white)
                                .background(symbol == "" ? .gray.opacity(0.20) : .indigo)
                                .clipShape(Circle())
                                .padding(.trailing, 5)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Spot", text: $spotName)
                                .font(.title)
                                .frame(maxWidth: .infinity)
                                .bold()
                            Text("\(streams.count) Song\(streams.count != 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    songList
                }
                .padding(.top, 5)
            }
            .navigationTitle("Add Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createSpot)
                        .disabled(notReady)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPicker(symbol: $symbol)
            }
        }
    }
    
    var songList: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text("Discovered")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.gray)
                Divider()
            }
            .padding(.horizontal)
            
            List {
                ForEach(streams, id: \.timestamp) { stream in
                    SongRowMini(stream: stream)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
        }
        .padding(.top)
    }
    
    func createSpot() {
        let spot = Spot(
            name: spotName,
            type: .place,
            iconName: symbol,
            latitude: streams.first?.latitude ?? 0,
            longitude: streams.first?.longitude ?? 0,
            shazamStreams: streams
        )
        
        modelContext.insert(spot)
        try? modelContext.save()
        
        dismiss()
    }
}

#Preview {
    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            NewSpot(streams: [ShazamStream.preview, ShazamStream.preview])
                .presentationDetents([.fraction(0.999)])
                .presentationBackground(.thickMaterial)
                .interactiveDismissDisabled()
                .presentationDragIndicator(.hidden)
        }
}
