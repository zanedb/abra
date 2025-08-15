//
//  MotionProvider.swift
//  Abra
//

import CoreMotion
import Foundation
import SwiftUI

@Observable class MotionProvider {
    private let motionManager = CMMotionManager()

    var isUpsideDown: Bool = false

    init() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else { return }
            self?.isUpsideDown = gravity.y > 0.7
        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
