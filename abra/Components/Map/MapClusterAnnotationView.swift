//
//  MapClusterAnnotationView.swift
//  abra
//
//  Created by Zane on 7/2/23.
//

import Foundation
import SwiftUI
import UIKit
import MapKit

// https://blog.kulman.sk/clustering-annotations-in-mkpampview/
final class MapClusterAnnotationView: MKAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        displayPriority = .defaultHigh
        collisionMode = .circle

        frame = CGRect(x: 0, y: 0, width: 40, height: 50)
        centerOffset = CGPoint(x: 0, y: -frame.size.height / 2)
        
        updateUI()
    }
    
    override var annotation: MKAnnotation? { didSet { updateUI() } }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateUI() {
        var count = 1
        
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            count = clusterAnnotation.memberAnnotations.count
        }
        
        let vc = UIHostingController(rootView: ClusterPin(count: count))
        vc.view.backgroundColor = .clear
        vc.view.frame = bounds
        
        addSubview(vc.view)
    }
    
//    func image(count: Int) -> UIImage {
//        let bounds = CGRect(origin: .zero, size: CGSize(width: 40, height: 40))
//
//        let renderer = UIGraphicsImageRenderer(bounds: bounds)
//        return renderer.image { _ in
//            // Fill full circle with tricycle color
//            UIColor.blue.setFill()
//            UIBezierPath(ovalIn: bounds).fill()
//
//            // Fill inner circle with white color
//            UIColor.white.setFill()
//            UIBezierPath(ovalIn: bounds.insetBy(dx: 8, dy: 8)).fill()
//
//            // Finally draw count text vertically and horizontally centered
//            let attributes: [NSAttributedString.Key: Any] = [
//                .foregroundColor: UIColor.black,
//                .font: UIFont.boldSystemFont(ofSize: 20)
//            ]
//
//            let text = "\(count)"
//            let size = text.size(withAttributes: attributes)
//            let origin = CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
//            let rect = CGRect(origin: origin, size: size)
//            text.draw(in: rect, withAttributes: attributes)
//        }
//    }
//
//    func setupUI(/*with count: Int*/) {
//        backgroundColor = .clear
//
//        if let cluster = annotation as? MKClusterAnnotation {
//            count = cluster.memberAnnotations.count
//        }
//
//        let vc = UIHostingController(rootView: MapCluster(count: count))
//        vc.view.backgroundColor = .clear
//        addSubview(vc.view)
//
//        vc.view.frame = bounds
//    }
}
