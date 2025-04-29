//
//  ToastProvider.swift
//  Abra
//

import SwiftUI

@Observable final class ToastProvider {
    private(set) var message: String = ""
    private(set) var type: ToastType = .info
    private(set) var symbolName: String?
    private(set) var action: (() -> Void)?
    private(set) var isVisible: Bool = false

    // Auto-dismiss timer
    private var dismissTask: Task<Void, Never>?

    /// Shows a toast message with the specified parameters
    /// - Parameters:
    ///   - message: The message to display
    ///   - type: The type of toast (default: .info)
    ///   - symbol: Optional SF Symbol name to override the default for the type
    ///   - action: Optional function that runs on tap gesture
    ///   - duration: How long to show the toast (default: 3 seconds)
    func show(message: String, type: ToastType = .info, symbol: String? = nil, action: (() -> Void)? = nil, duration: Double = 3.0) {
        // Cancel any existing dismiss task
        dismissTask?.cancel()

        // Update properties for the new toast
        self.message = message
        self.type = type
        self.action = action
        symbolName = symbol

        // Show the toast
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = true
        }

        // Schedule auto-dismiss after duration
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))

            // Check if task was cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isVisible = false
                    }
                }
            }
        }
    }

    /// Manually dismiss the currently showing toast
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil

        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = false
        }
    }
}

// MARK: - Environment Key and Values

private struct ToastProviderKey: EnvironmentKey {
    static let defaultValue = ToastProvider()
}

extension EnvironmentValues {
    var toastProvider: ToastProvider {
        get { self[ToastProviderKey.self] }
        set { self[ToastProviderKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Add a toast provider to the environment
    /// - Parameter provider: The toast provider to use (default: creates a new one)
    /// - Returns: A view with the toast provider in its environment
    func withToastProvider(_ provider: ToastProvider = ToastProvider()) -> some View {
        environment(\.toastProvider, provider)
    }

    /// Add toast overlay to the view
    /// - Parameter provider: The toast provider to use for displaying toasts
    /// - Returns: A view with the toast overlay
    func withToastOverlay(using provider: ToastProvider) -> some View {
        overlay {
            if provider.isVisible {
                Toast(
                    message: provider.message,
                    type: provider.type,
                    sfSymbol: provider.symbolName,
                    action: provider.action
                )
            }
        }
    }
}
