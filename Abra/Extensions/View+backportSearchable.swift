//
//  View+backportSearchable.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 11/26/25.
//

import SwiftUI

@available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension View {
    /// Backports `.searchable` with an `isPresented` Binding for different design on os18.
    func backportSearchable(
        text: Binding<String>,
        isPresented: Binding<Bool>,
        placement: SearchFieldPlacement = .automatic,
        prompt: LocalizedStringKey
    ) -> some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            // Disable on os 26
            return self
                .navigationBarTitleDisplayMode(.inline)
        } else {
            // Regular searchable support (iOS 15+ etc.)
            return self
                .searchable(text: text, isPresented: isPresented, placement: placement, prompt: prompt)
        }
    }
}
