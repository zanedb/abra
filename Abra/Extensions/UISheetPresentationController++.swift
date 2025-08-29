//
//  UISheetPresentationController++.swift
//  Abra
//

import UIKit

extension UISheetPresentationController.Detent {
    static func full() -> UISheetPresentationController.Detent {
        return value(forKey: "_fullDetent") as! UISheetPresentationController.Detent
    }

    static func small() -> UISheetPresentationController.Detent {
        return .custom { _ in
            112
        }
    }

    static func fraction(_ value: CGFloat) -> UISheetPresentationController.Detent {
        .custom(identifier: Identifier("Fraction:\(value)")) { context in
            context.maximumDetentValue * value
        }
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
}

extension UISheetPresentationController.Detent.Identifier {
    static func fraction(_ value: CGFloat) -> UISheetPresentationController.Detent.Identifier {
        return .init("Fraction:\(value)")
    }
}

extension UISheetPresentationController {
    var shouldScaleDownBehindDescendantSheets: Bool {
        get {
            return value(forKey: "shouldScaleDownBehindDescendantSheets") as? Bool ?? true
        } set {
            setValue(newValue, forKey: "shouldScaleDownBehindDescendantSheets")
        }
    }
}
