//
//  ViewModifiers.swift
//  Abra
//

import SwiftUI

struct InspectorSheetPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackgroundInteraction(.enabled)
            .presentationBackground(.thickMaterial)
            .presentationCornerRadius(18)
    }
}

extension View {
    /// Allows background interaction, sets the background to .thickMaterial, and sets preferred corner radius (18).
    func presentationInspector() -> some View {
        modifier(InspectorSheetPresentation())
    }
}
