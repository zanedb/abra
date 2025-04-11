//
//  RoundedButton.swift
//  Abra
//

import SwiftUI

struct RoundedButton: View {
    var label: String
    var systemImage: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
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
