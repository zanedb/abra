//
//  Toast.swift
//  Abra
//

import SwiftUI

enum ToastType {
    case error
    case success
    case warning
    case info
}

struct Toast: View {
    var message: String
    var type: ToastType = .info
    var sfSymbol: String?
    var action: (() -> Void)?

    var systemImage: String {
        guard sfSymbol == nil else { return sfSymbol! }

        switch type {
        case .error:
            return "exclamationmark.circle"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .info:
            return "hand.wave"
        }
    }

    var color: Color {
        switch type {
        case .error:
            return .red
        case .success:
            return .green
        case .warning:
            return .yellow
        case .info:
            return .blue
        }
    }

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundStyle(color.opacity(0.8))
                .shadow(color: .gray, radius: 0.1)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
        }
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Material.thick)
                .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1.5)
        }
        .position(x: UIScreen.main.bounds.width / 2, y: 26)
        .transition(.asymmetric(
            insertion: .push(from: .top).animation(.easeInOut(duration: 0.5)),
            removal: .push(from: .bottom).animation(.easeInOut(duration: 0.75))
        ))
        .onTapGesture {
            if let action = action {
                action()
            }
        }
    }
}

#Preview("Animated") {
    @Previewable @State var toast = ToastProvider()

    MapView(detent: .constant(.height(65)), shazams: [.preview])
        .environment(SheetProvider())
        .modelContainer(PreviewSampleData.container)
        .withToastProvider(toast)
        .withToastOverlay(using: toast)
        .onAppear {
            toast.show(message: "Location unavailable", type: .error, symbol: "location.slash.fill", action: { toast.dismiss() })
        }
}

#Preview("Non-Animated") {
    MapView(detent: .constant(.height(65)), shazams: [.preview])
        .environment(SheetProvider())
        .modelContainer(PreviewSampleData.container)
        .overlay {
            Toast(message: "Couldn’t save location", type: .error, sfSymbol: "location.slash.fill")
        }
}
