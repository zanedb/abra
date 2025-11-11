//
//  View+presentationInspector.swift
//  Abra
//

import SwiftUI

// Allows background interaction on medium detent (0.50)
// On os18: background to .thickMaterial, corner radius to 18
extension View {
    @ViewBuilder func presentationInspector() -> some View {
        if #available(iOS 26.0, *) {
            self
                .presentationBackgroundInteraction(
                    .enabled(upThrough: .fraction(0.50))
                )
        } else {
            self
                .presentationBackgroundInteraction(
                    .enabled(upThrough: .fraction(0.50))
                )
                .presentationBackground(.thickMaterial)
                .presentationCornerRadius(18)
        }
    }
}
