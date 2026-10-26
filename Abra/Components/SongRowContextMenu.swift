import SwiftUI
import UIKit

/// SwiftUI context-menu previews don't forward taps to their content. Use the
/// native preview commit callback so tapping the preview opens the song.
struct SongRowContextMenu<Preview: View>: UIViewRepresentable {
    var appleMusicURL: URL?
    var onTap: () -> Void
    var onViewSong: () -> Void
    var onRemoveFromSpot: (() -> Void)?
    var preview: Preview

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.addInteraction(UIContextMenuInteraction(delegate: context.coordinator))
        view.addGestureRecognizer(UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.tap)
        ))
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
        var parent: SongRowContextMenu
        private var actionAfterDismissal: (() -> Void)?
        private var menuHasEnded = false

        init(parent: SongRowContextMenu) {
            self.parent = parent
        }

        @objc func tap() {
            parent.onTap()
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            configurationForMenuAtLocation location: CGPoint
        ) -> UIContextMenuConfiguration? {
            menuHasEnded = false
            actionAfterDismissal = nil
            return UIContextMenuConfiguration(identifier: nil) { [self] in
                let controller = UIHostingController(rootView: parent.preview)
                controller.preferredContentSize = controller.sizeThatFits(
                    in: CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
                )
                return controller
            } actionProvider: { [self, weak sourceView = interaction.view] _ in
                var items: [UIMenuElement] = [
                    UIAction(title: "View Song", image: UIImage(systemName: "music.note")) { [self] _ in
                        showSongAfterMenuDismissal()
                    }
                ]
                if let url = parent.appleMusicURL {
                    items.append(UIMenu(options: .displayInline, children: [
                        UIAction(title: "Open in Music", image: UIImage(systemName: "arrow.up.forward")) { _ in
                            UIApplication.shared.open(url)
                        },
                        UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                            self?.share(url, from: sourceView)
                        }
                    ]))
                }
                if let onRemoveFromSpot = parent.onRemoveFromSpot {
                    items.append(UIMenu(options: .displayInline, children: [
                        UIAction(
                            title: "Remove from Spot",
                            image: UIImage(systemName: "mappin.slash"),
                            attributes: .destructive
                        ) { [self] _ in
                            performAfterMenuDismissal(onRemoveFromSpot)
                        }
                    ]))
                }
                return UIMenu(children: items)
            }
        }

        func showSongAfterMenuDismissal() {
            performAfterMenuDismissal(parent.onViewSong)
        }

        private func performAfterMenuDismissal(_ action: @escaping () -> Void) {
            if menuHasEnded {
                action()
            } else {
                actionAfterDismissal = action
            }
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willEndFor configuration: UIContextMenuConfiguration,
            animator: (any UIContextMenuInteractionAnimating)?
        ) {
            // UIAction delivery may happen before or after menu dismissal.
            // Read the pending action at completion so either order works.
            let finish = { [self] in
                menuHasEnded = true
                let action = actionAfterDismissal
                actionAfterDismissal = nil
                action?()
            }
            if let animator {
                animator.addCompletion(finish)
            } else {
                finish()
            }
        }

        func contextMenuInteraction(
            _ interaction: UIContextMenuInteraction,
            willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
            animator: any UIContextMenuInteractionCommitAnimating
        ) {
            animator.preferredCommitStyle = .dismiss
            // Changing the presented sheet before the menu finishes dismissing
            // can interrupt the transition. Open the song after that animation.
            animator.addCompletion(parent.onViewSong)
        }

        private func share(_ url: URL, from sourceView: UIView?) {
            guard let sourceView else { return }
            var responder: UIResponder? = sourceView
            while let current = responder, !(current is UIViewController) {
                responder = current.next
            }
            guard let presenter = responder as? UIViewController else { return }
            let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            controller.popoverPresentationController?.sourceView = sourceView
            controller.popoverPresentationController?.sourceRect = sourceView.bounds
            presenter.present(controller, animated: true)
        }
    }
}
