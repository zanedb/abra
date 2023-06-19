//
//  MapView.swift
//  abra
//
//  Created by Zane on 6/5/23.
//

import SwiftUI
import MapKit
import CoreData

struct UIKitMapView: UIViewRepresentable {
    let region: MKCoordinateRegion
    let streams: [SStream]
    let userTrackingMode: Binding<MKUserTrackingMode>
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let stream = annotation as? SStream else { return nil }
            
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "stream") as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "stream")
            
            annotationView.canShowCallout = true
            annotationView.glyphText = "🎵"
            annotationView.markerTintColor = .systemBlue
            annotationView.titleVisibility = .visible
            annotationView.detailCalloutAccessoryView = MapCalloutView(rootView: AnyView(SongSheet(stream: stream)))
            
            return annotationView
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = true // TODO: check for permissions first
        mapView.isRotateEnabled = false
        mapView.delegate = context.coordinator
        mapView.addAnnotations(streams)
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        if uiView.userTrackingMode != userTrackingMode.wrappedValue {
            uiView.setUserTrackingMode(userTrackingMode.wrappedValue, animated: true)
        }
    }
    
    typealias UIViewType = MKMapView
    
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
