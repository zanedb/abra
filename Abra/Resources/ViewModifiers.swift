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
    func body(content: Content) -> some View {
        content
            .introspect(.sheet, on: .iOS(.v18)) { sheetView in
                sheetView.prefersEdgeAttachedInCompactHeight = true
            }
    }
}

extension View {
    /// Allows background interaction, sets the background to .thickMaterial, and sets preferred corner radius (18).
    func presentationInspector() -> some View {
        modifier(InspectorSheetPresentation())
    }
    
    /// Only attach view to bottom edge, thereby disabling full-width presentation in landscape.
    func prefersEdgeAttachedInCompactHeight() -> some View {
        modifier(EdgeAttachedInCompactHeight())
    }
}
