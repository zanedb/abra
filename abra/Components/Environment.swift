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

