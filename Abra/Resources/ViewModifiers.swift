//
//  ViewModifiers.swift
//  Abra
//

import SwiftUI
import SwiftUIIntrospect

struct InspectorSheetPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackgroundInteraction(.enabled)
            .presentationBackground(.thickMaterial)
            .presentationCornerRadius(18)
    }
}

struct EdgeAttachedInCompactHeight: ViewModifier {
    var allowScrollingInMediumDetent: Bool = false
    
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
                
                // Optionally alow scrolling in medium detent (used on main "inspector")
                if allowScrollingInMediumDetent {
                    sheetView.prefersScrollingExpandsWhenScrolledToEdge = false
                }
            }
    }
}

extension View {
    /// Allows background interaction, sets the background to .thickMaterial, and sets preferred corner radius (18).
    func presentationInspector() -> some View {
        modifier(InspectorSheetPresentation())
    }
    
    /// Attach view to bottom leading edge, thereby disabling full-width presentation in landscape.
    func prefersEdgeAttachedInCompactHeight(allowScrollingInMediumDetent: Bool = false) -> some View {
        modifier(EdgeAttachedInCompactHeight(allowScrollingInMediumDetent: allowScrollingInMediumDetent))
    }
}

extension Font {
    /// Subheading style, used in "Discovered," "Moments," etc.
    static var subheading: Font {
        .system(size: 15, weight: .medium)
    }
    
    /// Big Title, used in SongView
    static var bigTitle: Font {
        .system(size: 18, weight: .bold)
    }
}
