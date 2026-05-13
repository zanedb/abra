//
//  MotionProvider.swift
//  Abra
//

import CoreMotion
import Foundation
import SwiftUI

@Observable class MotionProvider {
    private let motionManager = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    
    var isUpsideDown: Bool = false
    var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }
    var currentActivity: CMMotionActivity?
    var authorizationStatus: CMAuthorizationStatus = .notDetermined
    
    init() {
        updateAuthorizationStatus()
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
        activityManager.stopActivityUpdates()
    }
    
    // MARK: - Authorization
    
    private func updateAuthorizationStatus() {
        authorizationStatus = CMMotionActivityManager.authorizationStatus()
    }
    
    func requestPermission() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Motion activity is not available on this device")
            return
        }
        
        // Query activity to trigger permission prompt
        activityManager.queryActivityStarting(from: Date(), to: Date(), to: .main) { [weak self] _, error in
            if let error = error {
                print("Error requesting motion permission: \(error.localizedDescription)")
            }
            self?.updateAuthorizationStatus()
            
            // If authorized, start activity updates
            if self?.authorizationStatus == .authorized {
                self?.startActivityUpdates()
            }
        }
    }
    
    // MARK: - Device Motion
    
    private func startDeviceMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else { return }
            self?.isUpsideDown = gravity.y > 0.7
        }
    }
    
    // MARK: - Activity Updates
    
    func startActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        guard authorizationStatus == .authorized else { return }
        
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            self?.currentActivity = activity
        }
    }
    
    func stopActivityUpdates() {
        activityManager.stopActivityUpdates()
    }
}
// MARK: - Convenience Properties

extension MotionProvider {
    var isWalking: Bool {
        currentActivity?.walking ?? false
    }
    
    var isRunning: Bool {
        currentActivity?.running ?? false
    }
    
    var isCycling: Bool {
        currentActivity?.cycling ?? false
    }
    
    var isAutomotive: Bool {
        currentActivity?.automotive ?? false
    }
    
    var isStationary: Bool {
        currentActivity?.stationary ?? false
    }
    
    var activityConfidence: CMMotionActivityConfidence {
        currentActivity?.confidence ?? .low
    }
}
