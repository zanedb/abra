//
//  MapAnnotationView.swift
//  abra
//
//  Created by Zane on 7/2/23.
//

import Foundation
import SwiftUI
import MapKit

final class MapAnnotationView: MKAnnotationView {
    static let preferredClusteringIdentifier = String(describing: MapAnnotationView.self)
    public var stream: SStream?
    public var place: Place?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        clusteringIdentifier = MapAnnotationView.preferredClusteringIdentifier
        collisionMode = .circle
        
        frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        //centerOffset = CGPoint(x: 0, y: -frame.size.height / 2)
        
        if let stream = annotation as? SStream {
            print("sstream")
            canShowCallout = true
            detailCalloutAccessoryView = MapCalloutView(rootView: AnyView(SongSheet(stream: stream)))
            setupUI(stream)
        }
        
        if let place = annotation as? Place {
            print("place 2")
            canShowCallout = false // for now
            setupPlaceUI(place)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var annotation: MKAnnotation? {
        willSet {
            clusteringIdentifier = MapAnnotationView.preferredClusteringIdentifier
        }
    }
    
    func setupUI(_ stream: SStream) {
        let vc = UIHostingController(rootView: MapPin(stream: stream))
        vc.view.backgroundColor = .clear
        addSubview(vc.view)
        
        vc.view.frame = bounds
    }

    func setupPlaceUI(_ place: Place) {
        let vc = UIHostingController(rootView: PlacePin(place: place))
        vc.view.backgroundColor = .clear
        addSubview(vc.view)
        
        vc.view.frame = bounds
    }
}
