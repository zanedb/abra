//
//  SpotView.swift
//  Abra
//

import MapKit
import SwiftUI

struct SpotView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SheetProvider.self) private var view

    @Bindable var spot: Spot

    @State private var showingIconPicker: Bool = false

    private var notReady: Bool {
        spot.name == "" || spot.iconName == ""
    }

    private var count: Int {
        spot.shazamStreams?.count ?? 0
    }
    
    private var editing: Bool {
        view.detent == .fraction(0.999)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if editing {
                    heading

                    Text("Discovered")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

//                EditableList($spot.shazamStreams) { $stream in
//                    SongRowMini(stream: stream)
//                }
                List {
                    ForEach(spot.shazamStreams!) { stream in
                        SongRowMini(stream: stream)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .navigationTitle(
                editing
                    ? "Edit \(spot.type == .place ? "Spot" : "Vehicle")"
                    : spot.name == "" ? "\(count) Shazam\(count != 1 ? "s" : "")" : spot.name
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(notReady && !editing ? "+ Save Spot" : editing ? "Done" : "Edit", action: edit)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Play", action: play)
                        .disabled(notReady)
                }
            }
//            .onChange(of: streams) {
//                if count == 0 {
//                    dismiss()
//                }
//            }
            .popover(isPresented: $showingIconPicker) {
                IconPicker(symbol: $spot.iconName)
            }
            .onDisappear {
                // Destroy Spot if not saved
                // TODO: test if there are cases where this isn't triggered
                if notReady {
                    modelContext.delete(spot)
                }
            }
        }
    }

    private var heading: some View {
        HStack {
            Button(action: { showingIconPicker.toggle() }) {
                Image(systemName: spot.iconName == "" ? "plus.circle.fill" : spot.iconName)
                    .shadow(radius: 3, x: 0, y: 0)
                    .font(.system(size: spot.iconName == "" ? 24 : 28))
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
                    .background(spot.iconName == "" ? .gray.opacity(0.20) : .indigo)
                    .clipShape(Circle())
                    .padding(.trailing, 5)
            }
            VStack(alignment: .leading, spacing: 0) {
                TextField("Name", text: $spot.name)
                    .font(.title)
                    .frame(maxWidth: .infinity)
                    .bold()
                Text("\(count) Song\(count != 1 ? "s" : "")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func edit() {
        view.detent = .fraction(0.999)
    }

    private func play() {
        // TODO: Play a "station" based on this Spot's Shazams
    }
}

#Preview {
    @Previewable @State var view = SheetProvider()
    @Previewable var spot = Spot(name: "", type: .place, iconName: "", latitude: ShazamStream.preview.latitude, longitude: ShazamStream.preview.longitude, shazamStreams: [.preview, .preview])

    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            SpotView(spot: spot)
                .environment(view)
                .environment(MusicProvider())
                .presentationDetents([.fraction(0.50), .fraction(0.999)], selection: $view.detent)
                .presentationBackgroundInteraction(.enabled)
        }
}
