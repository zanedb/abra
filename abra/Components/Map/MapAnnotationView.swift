//
//  MapAnnotationView.swift
//  abra
//
//  Created by Zane on 7/2/23.
//

import Foundation
import SwiftUI
import MapKit

class SongAnnotation: NSObject, MKAnnotation {
    var stream: SStream
    var coordinate: CLLocationCoordinate2D
    var title: String?
    
    init(stream: SStream, title: String? = "") {
        self.stream = stream
        self.coordinate = stream.coordinate
        self.title = title
    }
}

final class MapAnnotationView: MKAnnotationView {
    static let preferredClusteringIdentifier = String(describing: MapAnnotationView.self)
    public var stream: SStream?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        clusteringIdentifier = MapAnnotationView.preferredClusteringIdentifier
        collisionMode = .circle
        
        frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        //centerOffset = CGPoint(x: 0, y: -frame.size.height / 2)
        
        if let songAnnotation = annotation as? SongAnnotation {
            canShowCallout = true
            detailCalloutAccessoryView = MapCalloutView(rootView: AnyView(SongSheet(stream: songAnnotation.stream)))
            setupUI(songAnnotation)
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
    
    func setupUI(_ annotation: SongAnnotation) {
        let vc = UIHostingController(rootView: MapPin(stream: annotation.stream))
        vc.view.backgroundColor = .clear
        addSubview(vc.view)
        
        vc.view.frame = bounds
    }
}

