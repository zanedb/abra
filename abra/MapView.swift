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
import NotificationCenter

enum MapDefaults {
    static let coordinate = CLLocationCoordinate2D(latitude: UserDefaults.standard.double(forKey: "LatCoord"), longitude: UserDefaults.standard.double(forKey: "LongCoord"))
    static let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
}

struct UIKitMapView: UIViewRepresentable {
    @EnvironmentObject private var vm: ViewModel
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: UIKitMapView
                
        init(_ parent: UIKitMapView) {
            self.parent = parent
        }
        
        // TODO: locate user after map open
        func mapViewDidStopLocatingUser(_ mapView: MKMapView) {}
        
        @MainActor func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            if (mapView.userTrackingMode != parent.vm.userTrackingMode) {
                parent.vm.userTrackingMode = mapView.userTrackingMode // keep view model variable up to date (there's gotta be a better way)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // TODO: use dequeueReusableAnimationView
            if let annotation = annotation as? SStream {
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) as? MapAnnotationView
                if view == nil {
                    view = MapAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
                }
                return view
            }
            
            if let annotation = annotation as? Place {
                print("place")
                return MapAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
            }
            
            if let annotation = annotation as? MKClusterAnnotation {
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? MapClusterAnnotationView
                if view == nil {
                    view = MapClusterAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
                }
                return view
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
        mapView.addAnnotations(vm.streams)
        mapView.addAnnotations(vm.places)
        
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
    
    func contextObjectsDidChange(_ notification: Notification) {
        print(notification)
    }
    
    private func cancellables(_ mapView: MKMapView) {
        let screen = UIScreen.main.bounds
        
        // TODO: use array of cancellables instead
        
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
                bottom: height - 99, // subtract smallest possible sheet
                right: 0
            )
        })
        
        // subscribe to updates on center
        vm.centerCancellable = vm.$center.sink(receiveValue: { newCenter in
            mapView.setCenter(newCenter, animated: true)
        })
        

        // define CoreData change methods
        // a better approach is prob possible, maybe look into NotificationCenter
        vm.addAnnotation = { annotation in
            if let stream = annotation as? SStream {
                mapView.addAnnotation(stream)
            }
        }
        
        vm.removeAnnotation = { annotation in
            if let stream = annotation as? SStream {
                mapView.removeAnnotation(stream)
            }
        }
        
        // TODO: test this one. i'm not sure if it'll remove the correct annotation if the object changed
        vm.updateAnnotation = { annotation in
            if let stream = annotation as? SStream {
                mapView.removeAnnotation(stream)
                mapView.addAnnotation(stream)
            }
        }
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {}
    
    typealias UIViewType = MKMapView
    
}
