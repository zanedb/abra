//
//  ContentView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import CoreLocation

// for blurred bg effects
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

struct ContentView: View {
    var locationManager: CLLocationManager?

    @State private var selection: Tab = .home
    
    enum Tab {
        case home
        case map
//        case playground
    }
    
    var body: some View {
        TabView(selection: $selection) {
            MainView()
                .tabItem {
                    Label("Home", systemImage: "shazam.logo")
                }
                .tag(Tab.home)
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(Tab.map)
//            Playground(listening: .constant(true), listShown: .constant(false))
//                .tabItem {
//                    Label("Playground", systemImage: "testtube.2")
//                }
//                .tag(Tab.playground)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
