//
//  RoundedButton.swift
//  Abra
//

import SwiftUI

struct RoundedButton: View {
    var label: String
    var systemImage: String
    var color: Color
    
    @State private var firstTap: Bool = true
    private var firstTapAction: () -> Void
    private var subsequentTapAction: () -> Void
    
    init(label: String, systemImage: String, color: Color, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.color = color
        self.firstTapAction = action
        self.subsequentTapAction = action
    }
    
    init (label: String, systemImage: String, color: Color, onFirstTap: @escaping () -> Void, onSubsequentTaps: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.color = color
        self.firstTapAction = onFirstTap
        self.subsequentTapAction = onSubsequentTaps
    }

    var body: some View {
        Button(action: { firstTap ? firstTapAction() : subsequentTapAction(); firstTap = false }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color, lineWidth: 2)
                    .frame(height: 44)

                Label(label, systemImage: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .tint(color)
            }
            .padding(.vertical, 3)
        }
    }
}

#Preview {
    @Previewable @State var locAuth: Bool = false
    @Previewable @State var micAuth: Bool = false
    
    VStack {
        RoundedButton(label: locAuth ? "" : "Location", systemImage: locAuth ? "checkmark" : "location.fill", color: locAuth ? .green : .blue, action: { locAuth.toggle() })
        RoundedButton(label: micAuth ? "" : "Microphone", systemImage: micAuth ? "checkmark" : "microphone.fill", color: micAuth ? .green : .orange, action: { micAuth.toggle() })
    }
    .padding()
}
