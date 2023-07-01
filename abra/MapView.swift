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
        let screen = UIScreen.main.bounds
        
        mapView.setRegion(vm.region, animated: true)
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = true
        mapView.delegate = context.coordinator
        mapView.addAnnotations(Array(streams)) // TODO: fix MapView not updating pins bc i'm passing in an Array
        
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
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {}
    
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
