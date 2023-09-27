//
//  NewPlace.swift
//  abra
//
//  Created by Zane on 7/2/23.
//

import SwiftUI
import MapKit

// don't worry we'll get to you too
/*
struct NewPlace: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: ViewModel
    
    @State private var placeName: String = ""
    @State private var radius: Double = 0.25
    @State private var showingSheet: Bool = false
    @State private var showingIconPicker: Bool = false
    @State private var symbol: String = ""
    
    let step = 0.25
    let range = 0.25...1
    
    var body: some View {
        NavigationStack {
            VStack() {
                Divider()
                VStack() {
                    HStack {
                        Button (action: { showingSheet = true }) {
                            Image(systemName: symbol == "" ? "plus.circle.fill" : symbol)
                                .shadow(radius: 3, x: 0, y: 0)
                                .font(.system(size: 24))
                                .frame(width: 80, height: 80)
                                .foregroundColor(.white)
                                .background(symbol == "" ? .gray.opacity(0.20) : .accentColor.opacity(0.20))
                                .cornerRadius(8.0)
                                .padding(.trailing, 5)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Place", text: $placeName)
                                .font(.title)
                                .bold()
                            Text("\(vm.currentSongs.count) Song\(vm.currentSongs.count != 1 ? "s" : "")")
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
                .navigationTitle("New Place")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            vm.createPlace(name: placeName, radius: radius, symbol: symbol)
                        }
                            .disabled(placeName == "" || symbol == "" || vm.currentSongsCount < 1)
                    }
                }
                .actionSheet(isPresented: $showingSheet) {
                    ActionSheet(
                        title: Text("Adorn Your Place"),
                        buttons:[
                            .default(Text("Choose Icon"), action: iconPicker),
                            .default(Text("Upload Image"), action: imagePicker),
                            .cancel()
                        ]
                    )}
                .sheet(isPresented: $showingIconPicker) {
                    IconPicker(symbol: $symbol)
                }
        }
    }
    
    func iconPicker() {
        showingSheet = false
        showingIconPicker = true
    }
    
    func imagePicker() {
        // TODO
    }
    
    var regionView: some View {
        VStack(alignment: .leading) {
            Text("Region")
                .font(.subheadline)
                .bold()
                .foregroundColor(.gray)
            Divider()
            
            HStack {
                Map(coordinateRegion: $vm.newPlaceRegion, annotationItems: vm.currentSongs) { song in
                    MapAnnotation(coordinate: song.coordinate, content: {
                        Text("fix later")
//                        MapPin(stream: song)
                    })
                }
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
                    Stepper(value: $radius,
                            in: range,
                            step: step) {
                        Text("Radius")
                            .foregroundColor(.gray)
                    } onEditingChanged: { z in
                        withAnimation {
                            // TODO: make this math make sense
                            vm.newPlaceRegion = MKCoordinateRegion(center: vm.newPlaceCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.005 * radius, longitudeDelta: 0.005 * radius))
                        }
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
                Text("In This Place")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.gray)
                Divider()
            }
                .padding(.horizontal)
            
            List {
                ForEach(vm.currentSongs, id: \.timestamp) { stream in
//                    SongRowMini(stream: stream)
                    Text("fuck a type check")
                }
            }
            .listStyle(.plain)
        }
            .padding(.top)
    }
}
 */

/*
#Preview {
    NavigationStack {
        Map(coordinateRegion: .constant(MKCoordinateRegion(center: MapDefaults.coordinate, span: MapDefaults.span)))
            .ignoresSafeArea(.all)
            .sheet(isPresented: .constant(true)) {
                NewPlace()
                    .presentationDetents([.large])
                    .interactiveDismissDisabled()
                    .presentationDragIndicator(.hidden)
                    .environmentObject(ViewModel())
            }
    }
}
*/
