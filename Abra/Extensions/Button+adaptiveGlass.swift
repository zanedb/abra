//
//  Button+adaptiveGlass.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 11/26/25.
//

import SwiftUI

extension View {
    @ViewBuilder func adaptiveGlass(
        prominent: Bool = false,
        tint: LinearGradient? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self
                    .buttonStyle(.glassProminent)
                    .tint(tint)
            } else {
                self
                    .buttonStyle(.glass)
            }
        } else {
            if tint != nil {
                self
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
            } else {
                self
                    .buttonStyle(.borderedProminent)
                    .tint(.secondary.opacity(0.1))
            }
        }
    }
}
