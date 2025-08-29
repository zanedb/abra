//
//  ViewModifiers.swift
//  Abra
//

import SwiftUI
import SwiftUIIntrospect

extension Font {
    /// Used in PhotoView
    static var buttonSmall: Font {
        .system(size: 20)
    }
    
    /// Button Image sizing in toolbars
    static var button: Font {
        .system(size: 24)
    }
    
    /// Used in .fullScreenCover environments
    static var buttonLarge: Font {
        .system(size: 32)
    }
}
