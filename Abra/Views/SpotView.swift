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
    
    @State private var showingIconDesigner: Bool = false
    
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                heading
                    .padding(.top, -40)
                    
                    }
                Photos(spot: spot)
                    .padding(.top, 8)
                    .foregroundStyle(.gray)
                        
                Text("\(spot.streams.count) Song\(spot.streams.count != 1 ? "s" : "")")
                    .font(.subheading)
                    .foregroundStyle(.gray)
                    .padding(.horizontal)
                    .padding(.top, 12)

                List(spot.streams) { stream in
                    SongRowMini(stream: stream, onTapGesture: {
                        if let appleMusicID = stream.appleMusicID {
                            music.playPause(id: appleMusicID)
                        }
                    })
                        .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: -4) {
                        Menu {
                            Button("Shuffle", systemImage: "shuffle", action: { spot.play(music, shuffle: true) })
                        } label: {
                            Image(systemName: spot.streams.compactMap(\.appleMusicID).contains(music.nowPlaying ?? "NIL") ? "pause.circle.fill" : "play.circle.fill")
                                .foregroundStyle(.gray)
                                .font(.button)
                                .symbolRenderingMode(.hierarchical)
                        } primaryAction: {
                            music.playPause(ids: spot.streams.compactMap(\.appleMusicID))
                        }
                        
                        DismissButton()
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
                    .font(.title)
                    .frame(maxWidth: 180, alignment: .leading)
                    .bold()
                Text(spot.description)
                    .foregroundStyle(.gray)
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
                        }
                    }
            }
        }
    }
}

#Preview {
    @Previewable var spot = Spot(name: "Me", symbol: "play.fill", latitude: ShazamStream.preview.latitude, longitude: ShazamStream.preview.longitude, shazamStreams: [.preview, .preview])

    Map(initialPosition: .automatic)
        .ignoresSafeArea(.all)
        .sheet(isPresented: .constant(true)) {
            SpotView(spot: spot)
                .environment(SheetProvider())
                .environment(MusicProvider())
                .presentationBackgroundInteraction(.enabled)
        }
}
