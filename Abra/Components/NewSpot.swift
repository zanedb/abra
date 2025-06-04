//
//  NewSpot.swift
//  Abra
//

import MapKit
import SwiftUI

struct NewSpot: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var spotName: String = ""
    @State private var symbol: String = ""
    @State private var showingIconPicker: Bool = false
    @State private var radius: Double = 0.25
    
    let step = 0.25
    let range = 0.25 ... 1
    
    private var notReady: Bool {
        spotName == "" || symbol == ""
    }
    
    private var position: Binding<MapCameraPosition> {
        Binding {
            let delta = radius / 69 // This is only “accurate” for latitude, since long is relative to lat’s distance from equator.
            return .region(MKCoordinateRegion(center: center, span: .init(latitudeDelta: delta, longitudeDelta: delta)))
        } set: { _ in }
    }
    
    var streams: [ShazamStream]
    var center: CLLocationCoordinate2D
    
    var body: some View {
        NavigationStack {
            VStack {
                Divider()
                VStack {
                    HStack {
                        Button(action: { showingIconPicker.toggle() }) {
                            Image(systemName: symbol == "" ? "plus.circle.fill" : symbol)
                                .shadow(radius: 3, x: 0, y: 0)
                                .font(.system(size: symbol == "" ? 24 : 32))
                                .frame(width: 80, height: 80)
                                .foregroundColor(.white)
                                .background(symbol == "" ? .gray.opacity(0.20) : .theme)
                                .cornerRadius(8.0)
                                .padding(.trailing, 5)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Spot", text: $spotName)
                                .font(.title)
                                .bold()
                            Text("\(streams.count) Song\(streams.count != 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    regionView
                    songList
                }
                .padding(.top, 5)
            }
            .navigationTitle("New Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        // TODO: create Spot
                    }
                    .disabled(notReady)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPicker(symbol: $symbol)
            }
        }
    }
    
    var regionView: some View {
        VStack(alignment: .leading) {
            Text("Region")
                .font(.subheadline)
                .bold()
                .foregroundColor(.gray)
            Divider()
            
            HStack {
                Map(position: position)
                    .frame(height: 110)
                    .cornerRadius(5)
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 100, height: 100)
                                .opacity(0.15)
                            Circle()
                                .stroke(Color.blue)
                                .frame(width: 100, height: 100)
                                .opacity(0.25)
                        }
                    )
                    .allowsHitTesting(false)
                VStack {
                    Text("\(radius, specifier: "%.2f") mi")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                    Stepper(value: $radius.animation(),
                            in: range,
                            step: step)
                    {
                        Text("Radius")
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.gray)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top)
        .padding(.horizontal)
    }
    
    var songList: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text("At This Spot")
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .padding(.top)
    }
}

#Preview {
    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            NewSpot(streams: [ShazamStream.preview], center: .init(latitude: 37.774722, longitude: -122.418231))
                .presentationDetents([.large])
                .interactiveDismissDisabled()
                .presentationDragIndicator(.hidden)
        }
}
