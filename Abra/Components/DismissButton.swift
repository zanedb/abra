//
//  DismissButton.swift
//  Abra
//

import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    var foreground: Color? = .gray
    var font: Font? = .button
    var action: (() -> Void)?

    var body: some View {
        Button(action: {
            if let action = action {
                action()
            } else {
                dismiss()
            }
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(foreground ?? .gray)
                .font(font)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
