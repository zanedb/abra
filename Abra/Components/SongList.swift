//
//  SongList.swift
//  Abra
//

import MapKit
import SwiftUI

struct SongList: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastProvider) private var toast
    @Environment(MusicProvider.self) private var music

    var type: SpotType = .place

    @State var streams: [ShazamStream]
    @Binding var detent: PresentationDetent

    @State private var expanded: Bool = false
    @State private var spotName: String = ""
    @State private var symbol: String = ""
    @State private var showingIconPicker: Bool = false

    private var notReady: Bool {
        spotName == "" || symbol == ""
    }

    init(group: ShazamStreamGroup, detent: Binding<PresentationDetent>) {
        self.streams = group.wrapped
        self.expanded = group.expanded
        self.type = group.type
        self._detent = detent
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if expanded {
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
                            TextField("Name", text: $spotName)
                                .font(.title)
                                .frame(maxWidth: .infinity)
                                .bold()
                            Text("\(streams.count) Song\(streams.count != 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    Text("Discovered")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

                EditableList($streams) { $stream in
                    SongRowMini(stream: stream)
                }
                .listStyle(.plain)
            }
            .navigationTitle(
                expanded
                    ? "Add \(type == .place ? "Spot" : "Vehicle")"
                    : "\(streams.count) Shazam\(streams.count != 1 ? "s" : "")"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if expanded {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: createSpot)
                            .disabled(notReady)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("+ Save Spot", action: expand)
                    }
                }
            }
            .onChange(of: streams) {
                if streams.count == 0 {
                    dismiss()
                }
            }
            .popover(isPresented: $showingIconPicker) {
                IconPicker(symbol: $symbol)
            }
        }
    }

    private func expand() {
        withAnimation {
            expanded.toggle()
        }

        detent = .fraction(0.999)
    }

    private func createSpot() {
        let spot = Spot(
            name: spotName,
            type: type,
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
    @Previewable @State var detent: PresentationDetent = .fraction(0.50)

    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            SongList(group: ShazamStreamGroup(wrapped: [.preview, .preview]), detent: $detent)
                .environment(MusicProvider())
                .presentationDetents([.fraction(0.50), .large])
                .presentationBackgroundInteraction(.enabled)
        }
}
