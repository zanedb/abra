//
//  MapView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import MapKit
import CoreData
import CoreLocation
import Combine

enum MapDefaults {
    static let coordinate = CLLocationCoordinate2D(latitude: 37.3316876, longitude: -122.0327261)
    static let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
}

class MapViewModel: ObservableObject {
    @Published var center: CLLocationCoordinate2D = MapDefaults.coordinate
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(center: MapDefaults.coordinate, span: MapDefaults.span)
    @Published var locateUserButtonPressed = false
    
    var centerCancellable: AnyCancellable?
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
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {}
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let stream = annotation as? SStream else { return nil }
            
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "stream") as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "stream")
            
            annotationView.canShowCallout = true
            annotationView.glyphImage = UIImage(systemName: "music.note")?.withTintColor(.systemRed)
            annotationView.titleVisibility = .visible
            annotationView.detailCalloutAccessoryView = MapCalloutView(rootView: AnyView(SongSheet(stream: stream)))
            
            return annotationView
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        
        mapView.setRegion(vm.region, animated: true)
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.delegate = context.coordinator
        mapView.addAnnotations(Array(streams)) // TODO: fix MapView not updating pins bc i'm passing in an Array
        
        // MARK: subscribe to updates on locateUserButton
        vm.locateUserButtonCancellable = vm.$locateUserButtonPressed.sink(receiveValue: { _ in
            if let userLocation = mapView.annotations.first(where: { $0 is MKUserLocation }) {
                // TODO: only adjust for bottomBar if detent is NOT PresentationDetent.height(65)
                mapView.setCenter(adjustForBottomBar(userLocation.coordinate, mapView), animated: true)
            }
        })
        
        // MARK: subscribe to updates on center
        vm.centerCancellable = vm.$center.sink(receiveValue: { newCenter in
            print(newCenter.latitude, newCenter.longitude)
            mapView.setCenter(adjustForBottomBar(newCenter, mapView), animated: true)
        })
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {}
    
    // MARK: why does this kind of work???? (https://stackoverflow.com/a/48350698)
    private func adjustForBottomBar(_ coord: CLLocationCoordinate2D, _ mapView: MKMapView) -> CLLocationCoordinate2D {
        guard (coord != MapDefaults.coordinate) else { return coord }
        
        var newCoord = coord
        newCoord.latitude -= (mapView.region.span.latitudeDelta * 0.25)
        return newCoord
    }
    
    typealias UIViewType = MKMapView
    
}

// safe comparison between two CLLocationCoordinate2D structs
// https://stackoverflow.com/a/10199213
extension CLLocationCoordinate2D: Equatable {
    static public func ==(lhs: Self, rhs: Self) -> Bool {
        fabs(lhs.latitude - rhs.latitude) <= 0.005 && fabs(lhs.longitude - rhs.longitude) <= 0.005
    }
}

/**
A custom callout view to be be passed as an MKMarkerAnnotationView, where you can use a SwiftUI View as it's base.
https://github.com/khuffie/swiftui-mapkit-callout
*/
class MapCalloutView: UIView {
    
    //create the UIHostingController we need. For now just adding a generic UI
    let body:UIHostingController<AnyView> = UIHostingController(rootView: AnyView(Text("Hello")) )

    
    /**
    An initializer for the callout. You must pass it in your SwiftUI view as the rootView property, wrapped with AnyView. e.g.
    MapCalloutView(rootView: AnyView(YourCustomView))
    
    Obviously you can pass in any properties to your custom view.
    */
    init(rootView: AnyView) {
        super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        body.rootView = AnyView(rootView)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    /**
    Ensures the callout bubble resizes according to the size of the SwiftUI view that's passed in.
    */
    private func setupView() {
        
        translatesAutoresizingMaskIntoConstraints = false
        
        //pass in your SwiftUI View as the rootView to the body UIHostingController
        //body.rootView = Text("Hello World * 2")
        body.view.translatesAutoresizingMaskIntoConstraints = false
        body.view.frame = bounds
        body.view.backgroundColor = nil
        //add the subview to the map callout
        addSubview(body.view)

        NSLayoutConstraint.activate([
            body.view.topAnchor.constraint(equalTo: topAnchor),
            body.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            body.view.leftAnchor.constraint(equalTo: leftAnchor),
            body.view.rightAnchor.constraint(equalTo: rightAnchor)
        ])
        
        sizeToFit()
        
    }
}
