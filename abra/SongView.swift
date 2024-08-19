//
//  SongView.swift
//  abra
//
//  Created by Zane on 6/19/23.
//

import SwiftUI
import MapKit
import SDWebImageSwiftUI

struct SongView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var vm: ViewModel
    
    var stream: ShazamStream
    
    var body: some View {
        if (vm.selectedDetent != PresentationDetent.height(65)) {
            VStack(alignment: .leading, spacing: 0) {
                card
                
                Text("Details")
                    .font(.headline)
                    .padding(.top)
                GroupBox {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading) {
                            Text("City")
                                .font(.subheadline)
                            Text(stream.city ?? "?")
                                .font(.title2)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Country")
                                .font(.subheadline)
                            Text(stream.country ?? "?")
                                .font(.title2)
                        }
                        Spacer()
                    }
                    .padding(.bottom)
                    HStack(spacing: 0) {
                        VStack(alignment: .leading) {
                            Text("Speed")
                                .font(.subheadline)
                            Text(String(stream.speed ?? 0))
                                .font(.title2)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Altitude")
                                .font(.subheadline)
                            Text(String(stream.altitude ?? 0))
                                .font(.title2)
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 5)
                
                /*
                Map(
                    coordinateRegion: .constant(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: stream.latitude, longitude: stream.longitude), span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001))),
                    annotationItems: [stream]
                ) { location in
                    MapMarker(coordinate: location.coordinate)
                }
                .frame(maxHeight: 200)
                .cornerRadius(5)
                .padding(.vertical)
                 */
                
                Spacer()
            }
            .padding()
            .transition(.asymmetric(
                insertion: .push(from: .bottom).animation(.easeInOut(duration: 0.25)),
                removal: .opacity.animation(.easeInOut(duration: 0.15)))
            )
            .navigationTitle(stream.definiteDate)
            .toolbar {
                ToolbarItem() {
                    Menu {
                        if (stream.appleMusicURL != nil) {
                            ShareLink(item: stream.appleMusicURL!) {
                                Label("Apple Music", systemImage: "arrow.up.forward.square")
                            }
                        }
                        Button(action: {}) { // generate a preview image ..?
                            Label("Preview", systemImage: "photo.stack")
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                vm.selectedSS = stream // Used to center map
            }
        } else {
            Spacer()
        }
    }
    
    var card: some View {
        HStack(alignment: .top) {
            WebImage(url: stream.artworkURL)
                .resizable()
                .placeholder {
                    ProgressView()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .padding(.trailing, 5)
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(3.0)
                .padding(.trailing, 5)
            VStack(alignment: .leading, spacing: 0) {
                Text(stream.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.80) : Color.black.opacity(0.80))
                    .font(.system(size: 17))
                    .padding(.bottom, 3)
                    .lineLimit(1)
                Text(stream.artist)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                    .font(.system(size: 14))
                    .padding(.bottom, 3)
                    .lineLimit(1)
                Text(stream.definiteDateAndTime)
                    .foregroundColor(Color.gray)
                    .font(.system(size: 13))
                Spacer()
                
                PlayButton(appleMusicID: stream.appleMusicID ?? "1486262969")
            }
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ShazamStream.self, configurations: config)

    let s = ShazamStream.preview
    return SongView(stream: s)
        .modelContainer(container)
        .environmentObject(ViewModel())
}
