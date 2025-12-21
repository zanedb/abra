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
            return "exclamationmark.circle.fill"
        case .success:
            return "checkmark.circle.fill"
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

    @State private var hapticTrigger = false

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .imageScale(.large)
                .font(.system(size: 15))
                .frame(width: 16, height: 12)
                .foregroundStyle(color)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)

            if action != nil {
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                    .padding(.leading, -4)
            }
        }
        .padding()
        .background {
            if #available(iOS 26.0, *) {
                ConcentricRectangle()
                    .fill(.clear)
                    .glassEffect()
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Material.thick)
            }
        }
        .position(x: UIScreen.main.bounds.width / 2, y: 38/*26*/) // TODO: place on top
        .transition(.asymmetric(
            insertion: .opacity.animation(.easeInOut(duration: 0.25)),
            removal: .opacity.animation(.easeInOut(duration: 0.25))
        ))
        .onTapGesture {
            if let action = action {
                action()
            }
        }
        .task(id: message) { hapticTrigger.toggle() }
        .sensoryFeedback(trigger: hapticTrigger) { oldValue, newValue in
            switch type {
            case .error:
                return .error
            case .success:
                return .success
            case .warning:
                return .warning
            case .info:
                return .selection
            }
        }
    }
}

#Preview("Animated") {
    @Previewable @State var toast = ToastProvider()

    ContentView()
        .withToastProvider(toast)
        .withToastOverlay(using: toast)
        .onAppear {
            toast.show(message: "Location unavailable", type: .error, symbol: "location.slash.fill")
        }
}

#Preview("Non-Animated") {
    ContentView()
        .overlay {
            Toast(message: "No match found", type: .info, sfSymbol: "shazam.logo.fill")
        }
}
