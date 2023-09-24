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

class ClusterViewModel: ObservableObject {
    @Published var count: Int = 0
    @Published var members: [MKAnnotation] = []
    @Published var coordinate: CLLocationCoordinate2D = MapDefaults.coordinate
}

// https://blog.kulman.sk/clustering-annotations-in-mkpampview/
final class MapClusterAnnotationView: MKAnnotationView {
    var vm: ClusterViewModel = ClusterViewModel()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        displayPriority = .defaultHigh
        collisionMode = .circle

        frame = CGRect(x: 0, y: 0, width: 40, height: 50)
        centerOffset = CGPoint(x: 0, y: -frame.size.height / 2)
        
        canShowCallout = true
        detailCalloutAccessoryView = MapCalloutView(rootView: AnyView(ClusterList(cvm: self.vm)))
        
        updateUI()
        view()
    }
    
    override var annotation: MKAnnotation? { didSet { updateUI() } }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateUI() {
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            self.vm.count = clusterAnnotation.memberAnnotations.count
            self.vm.members = clusterAnnotation.memberAnnotations
            self.vm.coordinate = clusterAnnotation.coordinate
        }
    }
    
    private func view() {
        let vc = UIHostingController(rootView: ClusterPin(vm: self.vm))
        vc.view.backgroundColor = .clear
        vc.view.frame = bounds
        
        addSubview(vc.view)
    }
}

struct ClusterList: View {
    @StateObject var cvm: ClusterViewModel
    @EnvironmentObject private var vm: ViewModel
    
    var body: some View {
        Button { vm.newPlace(cvm.members, cvm.coordinate) } label: {
            Label("New Place", systemImage: "plus")
        }
    }
}
