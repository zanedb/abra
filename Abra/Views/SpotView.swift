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
    @Environment(MusicProvider.self) private var music

    @Bindable var spot: Spot

    @State private var minimized: Bool = false
    @State private var showingIconPicker: Bool = false
    @State private var showingHeader: Bool

    init(spot: Spot) {
        self.spot = spot
        _showingHeader = State(initialValue: spot.name != "" && spot.iconName != "")
    }

    private var count: Int {
        spot.shazamStreams?.count ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if showingHeader {
                    heading
                        .padding(.top, -40)

                    if !minimized {
                        Text("\(count) Song\(count != 1 ? "s" : "")")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.top, 12)
                    }
                }

                if !minimized {
                    List {
                        ForEach(spot.shazamStreams!) { stream in
                            Button(action: {
                                view.stream = stream
                                view.spot = nil
                            }) {
                                SongRowMini(stream: stream)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
            }
            .navigationTitle(showingHeader ? "" : "\(count) Song\(count != 1 ? "s" : "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showingHeader {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("+ Save Spot", action: edit)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: -2) {
                        Button(action: { spot.play(music) }) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                                .symbolRenderingMode(.hierarchical)
                        }
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
            .popover(isPresented: $showingIconPicker) {
                IconPicker(symbol: $spot.iconName)
            }
            .onDisappear {
                // Destroy Spot if not saved
                // TODO: test if there are cases where this isn't triggered
                if spot.name == "" || spot.iconName == "" {
                    modelContext.delete(spot)
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: {
            minimized = ($0.height < 100) ? true : false
        }
    }

    private var heading: some View {
        HStack {
            Button(action: { showingIconPicker.toggle() }) {
                Image(systemName: spot.iconName == "" ? "plus.circle.fill" : spot.iconName)
                    .font(.system(size: minimized ? 12 : spot.iconName == "" ? 24 : 28))
                    .frame(width: minimized ? 40 : 80, height: minimized ? 40 : 80)
                    .foregroundColor(.white)
                    .background(spot.iconName == "" ? .gray.opacity(0.20) : .indigo)
                    .clipShape(Circle())
                    .padding(.trailing, 5)
            }
            VStack(alignment: .leading, spacing: 0) {
                TextField("Name", text: $spot.name)
                    .font(minimized ? .title2 : .title)
                    .frame(maxWidth: minimized ? 220 : 180, alignment: .leading)
                    .bold()
                Text(spot.type == .place ? spot.cityState : "Vehicle")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func edit() {
        withAnimation {
            showingHeader.toggle()
        }
    }
}

#Preview {
    @Previewable @State var view = SheetProvider()
    @Previewable var spot = Spot(name: "Me", type: .place, iconName: "play", latitude: ShazamStream.preview.latitude, longitude: ShazamStream.preview.longitude, shazamStreams: [.preview, .preview])

    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            SpotView(spot: spot)
                .environment(view)
                .environment(MusicProvider())
                .presentationDetents([.height(65), .fraction(0.50), .fraction(0.999)], selection: $view.detent)
                .presentationBackgroundInteraction(.enabled)
        }
}
