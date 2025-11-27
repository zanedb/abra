//
//  View+backportCircleSymbolVariant.swift
//  Suite
//
//  Created by Daniel Eden on 27/08/2025.
//  Modified for Abra.
//

import SwiftUI

@available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension View {
    func backportCircleSymbolVariant(foreground: Color? = nil, fill: Bool = true) -> some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return self
                .font(.headline)
                .symbolVariant(fill ? .fill : .none)
        } else {
            return self
                .font(foreground != nil ? .buttonLarge : .button)
                .foregroundStyle(foreground ?? .gray)
                .symbolVariant(.circle.fill)
//                .symbolVariant(fill ? .circle.fill : .circle)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                VStack {}
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(action: {}) {
                                Image(systemName: "play")
                            }
                            .backportCircleSymbolVariant()
                        }
                    }
            }
        }
}
