//
//  View+PresentationInspector.swift
//  Abra
//

import SwiftUI

struct PresentationInspector: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.50)))
            .presentationBackground(.thickMaterial)
            .presentationCornerRadius(18)
    }
}

extension View {
    /// Allows background interaction, sets the background to .thickMaterial, and sets preferred corner radius (18).
    func presentationInspector() -> some View {
        modifier(PresentationInspector())
    }
}
