//
//  DismissButton.swift
//  Abra
//

import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    var foreground: Color? = nil
    var font: Font? = .buttonSmall
    var action: (() -> Void)?

    var body: some View {
        Button(action: {
            if let action = action {
                action()
            } else {
                dismiss()
            }
        }) {
            Image(systemName: "xmark")
        }
        .backportCircleSymbolVariant(foreground: foreground)
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                VStack {}
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            DismissButton()
                        }
                    }
            }
        }
}
