//
//  LocateButton.swift
//  abra
//
//  Created by Zane on 6/30/23.
//

import SwiftUI

struct LocateButton: View {
    @EnvironmentObject var vm: MapViewModel
    
    var body: some View {
        Button(action: {
            switch(vm.userTrackingMode) {
            case .none:
                vm.userTrackingMode = .follow
            case .follow:
                vm.userTrackingMode = .followWithHeading
            case .followWithHeading:
                vm.userTrackingMode = .none
            default:
                vm.userTrackingMode = .none
            }
        }) {
            Image(
                systemName: vm.userTrackingMode == .follow
                ? "location.fill"
                : (
                    vm.userTrackingMode == .followWithHeading
                        ? "location.north.line.fill"
                        : "location"
                )
            )
                .font(.system(size: 18))
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
            .foregroundColor(.primary.opacity(0.60))
            .background(.ultraThickMaterial)
            .buttonStyle(ScaleButtonStyle(enabled: vm.userTrackingMode != .none))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.10))
            )
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    var enabled: Bool
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && enabled ? 0 : 1)
    }
}

struct LocateButton_Previews: PreviewProvider {
    static var previews: some View {
        LocateButton()
            .environmentObject(MapViewModel())
    }
}
