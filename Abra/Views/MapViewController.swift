//
//  MapViewController.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 5/30/25.
//

import MapKit
import SwiftUI
import UIKit

struct MyView: UIViewControllerRepresentable {
    typealias UIViewControllerType = MapViewController
    
    func makeUIViewController(context: Context) -> MapViewController {
        let vc = MapViewController()
        // Do some configurations here if needed.
        return vc
    }
        
    func updateUIViewController(_ uiViewController: MapViewController, context: Context) {
        // Updates the state of the specified view controller with new information from SwiftUI.
    }
}

class MapViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let viewController = UIViewController()
        viewController.isModalInPresentation = true
        viewController.preferredContentSize = CGSize(width: 400, height: view.frame.height)
        
        viewController.sheetPresentationController?.prefersGrabberVisible = false
        viewController.sheetPresentationController?.detents = [.medium(), .large(allowsScaling: false), .full()]
        viewController.sheetPresentationController?.largestUndimmedDetentIdentifier = .large
        viewController.sheetPresentationController?.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        
        viewController.sheetPresentationController?.setValue(1, forKey: "horizontalAlignment")
        viewController.sheetPresentationController?.setValue(true, forKey: "wantsBottomAttached")
        viewController.sheetPresentationController?.setValue(10, forKey: "marginInRegularWidthRegularHeight")
        
        let textField = UITextField()
        textField.placeholder = "Text"
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        viewController.view.addSubview(textField)
        
        present(viewController, animated: false)
    }
}

extension UISheetPresentationController.Detent {
    static func full() -> UISheetPresentationController.Detent {
        return value(forKey: "_fullDetent") as! UISheetPresentationController.Detent
    }
    
    static func large(allowsScaling: Bool) -> UISheetPresentationController.Detent {
        if allowsScaling {
            return .large()
        } else {
            return .custom { context in
                context.maximumDetentValue * 0.999777
            }
        }
    }
    
//    static func small() -> UISheetPresentationController.Detent {
//        return .custom { context in
//            // height is the view.frame.height of the view controller which presents this bottom sheet
//            context.height * 10
//        } as! UISheetPresentationController.Detent
//    }
}
