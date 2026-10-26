import SwiftUI
import UIKit

/// Keeps the outgoing sheet visible while its content changes underneath it.
/// Used when a directly opened Spot has no Song sheet beneath it to dismiss to.
@MainActor
final class SheetRevealTransition {
    private weak var sourceView: UIView?

    func reveal(_ update: () -> Void) {
        guard let sourceView, let window = sourceView.window,
            let sheet = presentedSheet(containing: sourceView),
            let snapshot = sheet.snapshotView(afterScreenUpdates: true)
        else {
            update()
            return
        }

        snapshot.frame = sheet.convert(sheet.bounds, to: window)
        snapshot.isUserInteractionEnabled = true
        window.addSubview(snapshot)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, update)

        // Let SwiftUI install SongView underneath the outgoing Spot first.
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
                if UIAccessibility.isReduceMotionEnabled {
                    snapshot.alpha = 0
                } else {
                    snapshot.transform = CGAffineTransform(
                        translationX: 0,
                        y: window.bounds.maxY - snapshot.frame.minY
                    )
                }
            } completion: { _ in
                snapshot.removeFromSuperview()
            }
        }
    }

    private func presentedSheet(containing sourceView: UIView) -> UIView? {
        var responder: UIResponder? = sourceView
        while let current = responder {
            if let controller = current as? UIViewController,
                controller.presentingViewController != nil,
                let presentedView = controller.presentationController?.presentedView
            {
                return presentedView
            }
            responder = current.next
        }
        return nil
    }

    struct Anchor: UIViewRepresentable {
        let transition: SheetRevealTransition

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            transition.sourceView = view
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            transition.sourceView = uiView
        }
    }
}
