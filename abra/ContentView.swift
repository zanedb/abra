//
//  ContentView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import CoreLocation
import MapKit
import MusicKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject private var shazam = Shazam()
    @StateObject var music = MusicController.shared.music
    
    @State private var userTrackingMode: MKUserTrackingMode = .none
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3316876, longitude: -122.0327261), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    
    @State private var sheetPresented: Bool = true
    @State private var sheetContentHeight = CGFloat(0)
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SStream.timestamp, ascending: false)],
        animation: .default)
    private var streams: FetchedResults<SStream>
    
    var body: some View {
        ZStack(alignment: .top) {
            UIKitMapView(region: region, streams: Array(streams), userTrackingMode: $userTrackingMode)
                .edgesIgnoringSafeArea(.all)
                .sheet(isPresented: $sheetPresented) {
                    UISheet {
                        SheetView(streams: Array(streams), shazam: shazam)
                            .padding(.top, 18)
                    }
                        .interactiveDismissDisabled()
                        .ignoresSafeArea()
                        .readSize { newSize in
                            sheetContentHeight = newSize.height
                            print(sheetContentHeight) // TODO: hide elements on small content height
                        }
                }

            HStack(alignment: .top) {
                Spacer()
                VStack {
                    Button(action: { userTrackingMode = userTrackingMode == .follow ? .none : .follow }) {
                        Image(systemName: userTrackingMode == .follow ? "location.fill" : "location")
                            .font(.system(size: 20))
                    }
                        .frame(width: 44, height: 44)
                        .background(.ultraThickMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.10))
                        )
                        .cornerRadius(8)
                }
                    .shadow(color: Color.primary.opacity(0.10), radius: 5, x: 0, y: 2)
            }.padding(.trailing)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
