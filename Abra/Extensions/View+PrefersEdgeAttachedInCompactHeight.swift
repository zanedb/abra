//
//  View+PrefersEdgeAttachedInCompactHeight.swift
//  Abra
//

import SwiftUI
import SwiftUIIntrospect

struct PrefersEdgeAttachedInCompactHeight: ViewModifier {
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
    /// Attach view to bottom leading edge, thereby disabling full-width presentation in landscape.
    func prefersEdgeAttachedInCompactHeight() -> some View {
        modifier(PrefersEdgeAttachedInCompactHeight())
    }
}
