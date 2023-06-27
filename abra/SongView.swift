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
    @Environment(\.selectedDetent) private var selectedDetent
    
    var stream: SStream
    
    var body: some View {
        if (selectedDetent != PresentationDetent.height(65)) {
            VStack(alignment: .leading, spacing: 0) {
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
                        Text(stream.trackTitle ?? "Unknown Song")
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.80) : Color.black.opacity(0.80))
                            .font(.system(size: 17))
                            .padding(.bottom, 3)
                            .lineLimit(1)
                        Text(stream.artist ?? "Unknown Artist")
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                            .font(.system(size: 14))
                            .padding(.bottom, 3)
                            .lineLimit(1)
                        Text(stream.timestamp?.formatted(.dateTime.hour().minute().timeZone()) ?? "Something went wrong")
                            .foregroundColor(Color.gray)
                            .font(.system(size: 13))
                        Spacer()
                        
                        PlayButton(appleMusicID: stream.appleMusicID!)
                    }
                    Spacer()
                }
                .fixedSize(horizontal: false, vertical: true)
                
                
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
                            Text(String(stream.speed))
                                .font(.title2)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Altitude")
                                .font(.subheadline)
                            Text(String(stream.altitude))
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
        } else {
            Spacer()
        }
    }
}

struct SongView_Previews: PreviewProvider {
    static var previews: some View {
        SongView(stream: SStream.example)
    }
}
