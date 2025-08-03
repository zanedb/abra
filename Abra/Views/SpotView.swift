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
    
    @Namespace var animation
    
    @Bindable var spot: Spot
    
    @State private var minimized: Bool = false
    @State private var showingIconDesigner: Bool = false
    @State private var selectedEvent: Event?
    
    private var songCount: Int {
        spot.shazamStreamsByEvent(selectedEvent).count
    }
    
    private var eventCount: Int {
        spot.events?.count ?? 0
    }
    
    private var trackIDs: [String] {
        spot.shazamStreamsByEvent(selectedEvent).compactMap(\.appleMusicID)
    }
    
    private var isPlaying: Bool {
        trackIDs.contains(music.nowPlaying ?? "NIL")
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                heading
                    .padding(.top, -40)
                    
                if !minimized {
                    if eventCount > 0 {
                        Text("\(eventCount) Event\(eventCount != 1 ? "s" : "")")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.top, 12)
                            
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                events
                            }
                            .padding(.horizontal)
                        }
                    }
                        
                    Text("\(songCount) Song\(songCount != 1 ? "s" : "")")
                        .font(.subheading)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    List(spot.shazamStreamsByEvent(selectedEvent)) { stream in
                        Button(action: {
                            if let appleMusicID = stream.appleMusicID {
                                music.playPause(id: appleMusicID)
                            }
                        }) {
                            SongRowMini(stream: stream)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: -2) {
                        Button(action: { music.playPause(ids: trackIDs) }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
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
            .popover(isPresented: $showingIconDesigner) {
                IconDesigner(symbol: $spot.symbol, color: $spot.color, animation: animation, id: spot.persistentModelID)
                    .presentationDetents([.fraction(0.999)])
                    .presentationBackground(.thickMaterial)
                    .presentationCornerRadius(14)
            }
            .onDisappear {
                // Destroy Spot if not saved
                // TODO: test if there are cases where this isn't triggered
                if spot.name == "" || spot.symbol == "" {
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
            Button(action: { showingIconDesigner.toggle() }) {
                SpotIcon(symbol: spot.symbol, color: Color(spot.color), size: minimized ? 40 : 80)
                    .matchedTransitionSource(id: spot.id, in: animation)
                    .padding(.trailing, minimized ? 2 : 4)
            }
            VStack(alignment: .leading, spacing: 0) {
                TextField("Name", text: $spot.name)
                    .font(minimized ? .title2 : .title)
                    .frame(maxWidth: minimized ? 220 : 180, alignment: .leading)
                    .bold()
                Menu {
                    Button("Place", systemImage: spot.type == .place ? "checkmark" : "", action: { spot.type = .place })
                    Button("Vehicle", systemImage: spot.type == .vehicle ? "checkmark" : "", action: { spot.type = .vehicle })
                } label: {
                    Text(spot.description)
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var events: some View {
        ForEach(spot.events!) { event in
            Button(action: {
                withAnimation {
                    selectedEvent = selectedEvent == event ? nil : event
                }
            }) {
                Text(event.name)
                    .font(.headline)
                    .padding(12)
                    .background {
                        if selectedEvent == event {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.background)
                        }
                    }
            }
            .contextMenu {
                Button(role: .destructive, action: { modelContext.delete(event) }, label: {
                    Label("Delete", systemImage: "trash")
                })
            }
        }
    }
}

#Preview {
    @Previewable @State var view = SheetProvider()
    @Previewable var spot = Spot(name: "Me", type: .place, symbol: "play.fill", latitude: ShazamStream.preview.latitude, longitude: ShazamStream.preview.longitude, shazamStreams: [.preview, .preview])

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
