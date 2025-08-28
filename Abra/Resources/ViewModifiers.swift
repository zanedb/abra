//
//  ViewModifiers.swift
//  Abra
//

import SwiftUI
import SwiftUIIntrospect

struct InspectorSheetPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.50)))
            .presentationBackground(.thickMaterial)
            .presentationCornerRadius(18)
    }
}

struct EdgeAttachedInCompactHeight: ViewModifier {
    func body(content: Content) -> some View {
        content
            .introspect(.sheet, on: .iOS(.v18)) { sheetView in
                sheetView.presentedViewController.preferredContentSize = CGSize(width: 400, height: sheetView.frameOfPresentedViewInContainerView.height)
                
                // Disable full-width in landscape
                sheetView.prefersEdgeAttachedInCompactHeight = true
                sheetView.widthFollowsPreferredContentSizeWhenEdgeAttached = true
                
                // Leading-aligned sheet in landscape/iPad (width-dependent)
                sheetView.setValue(true, forKey: "tucksIntoUnsafeAreaInCompactHeight")
                sheetView.setValue(1, forKey: "horizontalAlignment")
                sheetView.setValue(true, forKey: "wantsBottomAttached")
                sheetView.setValue(10, forKey: "marginInRegularWidthRegularHeight")
                
                // Full height without scaling down
                let controller = sheetView as UISheetPresentationController
                controller.shouldScaleDownBehindDescendantSheets = false
            }
    }
}

extension View {
    /// Allows background interaction, sets the background to .thickMaterial, and sets preferred corner radius (18).
    func presentationInspector() -> some View {
        modifier(InspectorSheetPresentation())
    }
    
    /// Attach view to bottom leading edge, thereby disabling full-width presentation in landscape.
    func prefersEdgeAttachedInCompactHeight() -> some View {
        modifier(EdgeAttachedInCompactHeight())
    }
}

extension UISheetPresentationController.Detent {
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

extension Font {
    /// Subheading style, used in "Discovered," "Moments," etc.
    static var subheading: Font {
        .system(.subheadline, weight: .medium)
    }
    
    /// Big Title, used in SongView
    static var bigTitle: Font {
        .system(.headline)
    }
    
    /// Used in PhotoView
    static var buttonSmall: Font {
        .system(size: 20)
    }
    
    /// Button Image sizing in toolbars
    static var button: Font {
        .system(size: 24)
    }
    
    /// Used in .fullScreenCover environments
    static var buttonLarge: Font {
        .system(size: 32)
    }
}
