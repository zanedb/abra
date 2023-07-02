//
//  MapView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import MapKit
import CoreData
import Combine

enum MapDefaults {
    static let coordinate = CLLocationCoordinate2D(latitude: UserDefaults.standard.double(forKey: "LatCoord"), longitude: UserDefaults.standard.double(forKey: "LongCoord"))
    static let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
}

class MapViewModel: ObservableObject {
    @Published var center: CLLocationCoordinate2D = MapDefaults.coordinate
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(center: MapDefaults.coordinate, span: MapDefaults.span)
    @Published var userTrackingMode: MKUserTrackingMode = .none
    @Published var selectedDetent: PresentationDetent = PresentationDetent.fraction(0.5)
    @Published var detentHeight: CGFloat = 0
    
    var centerCancellable: AnyCancellable?
    var detentCancellable: AnyCancellable?
    var locateUserButtonCancellable: AnyCancellable?
}

struct UIKitMapView: UIViewRepresentable {
    var streams: FetchedResults<SStream>
    @EnvironmentObject private var vm: MapViewModel
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: UIKitMapView
                
        init(_ parent: UIKitMapView) {
            self.parent = parent
        }
        
        // TODO: locate user after map open
        func mapViewDidStopLocatingUser(_ mapView: MKMapView) {}
        
        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            if (mapView.userTrackingMode != parent.vm.userTrackingMode) {
                parent.vm.userTrackingMode = mapView.userTrackingMode // keep view model variable up to date (there's gotta be a better way)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let annotation = annotation as? SongAnnotation {
                return MapAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
            }
            
            if let annotation = annotation as? MKClusterAnnotation {
                return MapClusterAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
            }
            
            return nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        
        mapView.setRegion(vm.region, animated: true)
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = true
        mapView.delegate = context.coordinator
        
        // TODO: write this well
        streams.forEach { stream in
            let annotation = SongAnnotation(stream: stream)
            mapView.addAnnotation(annotation)
        }
        
        replaceCompass(mapView)
        cancellables(mapView)
        
        return mapView
    }
    
    private func replaceCompass(_ mapView: MKMapView) {
        // replace default compass so it doesn't overlap with locatebutton
        mapView.showsCompass = false
        let compass = MKCompassButton(mapView: mapView)
        compass.frame.origin = CGPoint(x: 10, y: 56)//CGPoint(x: screen.size.width - 53, y: 106)
        compass.compassVisibility = .adaptive
        compass.layer.shadowColor = UIColor.black.cgColor
        compass.layer.shadowOffset = CGSize(width: 0, height: 2)
        compass.layer.shadowOpacity = 0.10
        compass.layer.shadowRadius = 3.0
        mapView.addSubview(compass)
    }
    
    private func cancellables(_ mapView: MKMapView) {
        let screen = UIScreen.main.bounds
        
        // set user tracking mode on update
        vm.locateUserButtonCancellable = vm.$userTrackingMode.sink(receiveValue: { mode in
            mapView.setUserTrackingMode(mode, animated: true)
        })
        
        // update map inset based on detent height
        vm.detentCancellable = vm.$detentHeight.sink(receiveValue: { height in
            if (vm.userTrackingMode == .follow) { vm.userTrackingMode = .none } // don't make ui jump
            if (vm.userTrackingMode == .followWithHeading && height > ((1/2) * (screen.size.height))) { return } // stop after certain height
            
            mapView.layoutMargins = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: height - 99,
                right: 0
            )
        })
        
        // subscribe to updates on center
        vm.centerCancellable = vm.$center.sink(receiveValue: { newCenter in
            mapView.setCenter(newCenter, animated: true)
        })
    }
    
    // TODO: test this!
    func updateUIView(_ mapView: MKMapView, context: Context) {
        let existing = mapView.annotations.compactMap { $0 as? SStream }
        let diff = Array(streams).difference(from: existing) { $0 === $1 }

        for change in diff {
            switch change {
            case .insert(_, let element, _): mapView.addAnnotation(element)
            case .remove(_, let element, _): mapView.removeAnnotation(element)
            }
        }
    }
    
    typealias UIViewType = MKMapView
    
}
