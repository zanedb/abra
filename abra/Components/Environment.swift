//
//  Environment.swift
//  abra
//
//  Created by Zane on 7/1/23.
//

import Foundation
import SwiftUI

struct DetentKey: EnvironmentKey {
    static let defaultValue: PresentationDetent = .fraction(0.50)
}

extension EnvironmentValues {
    var selectedDetent: PresentationDetent {
        get { self[DetentKey.self] }
        set { self[DetentKey.self] = newValue }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        guard let nextValue = nextValue() else { return }
        value = nextValue
    }
}

private struct ReadHeightModifier: ViewModifier {
    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: HeightPreferenceKey.self, value: geometry.size.height)
        }
    }

    func body(content: Content) -> some View {
        content.background(sizeView)
    }
}

extension View {
    func readHeight() -> some View {
        self
            .modifier(ReadHeightModifier())
    }
}
