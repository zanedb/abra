import MapKit
import UIKit

/// Draws the saved uncertainty area growing from, or shrinking to, its center.
final class ApproximateAreaRenderer: MKOverlayRenderer {
    private let progressLock = NSLock()
    private var progress: CGFloat = 0
    private let fill = UIColor.systemBlue.withAlphaComponent(0.07).cgColor
    private let stroke = UIColor.systemBlue.withAlphaComponent(0.55).cgColor
    private var animationTask: Task<Void, Never>?

    deinit {
        animationTask?.cancel()
    }

    private var currentProgress: CGFloat {
        progressLock.withLock { progress }
    }

    private func setProgress(_ value: CGFloat) {
        progressLock.withLock { progress = value }
        setNeedsDisplay()
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let progress = currentProgress
        guard progress > 0 else { return }
        let bounds = rect(for: overlay.boundingMapRect)
        let area = bounds.insetBy(
            dx: bounds.width * (1 - progress) / 2,
            dy: bounds.height * (1 - progress) / 2
        )
        context.saveGState()
        context.setFillColor(fill)
        context.setStrokeColor(stroke)
        context.setLineWidth(2 / zoomScale)
        context.addEllipse(in: area)
        context.drawPath(using: .fillStroke)
        context.restoreGState()
    }

    @MainActor
    func animate(to target: CGFloat, completion: (() -> Void)? = nil) {
        animationTask?.cancel()
        animationTask = nil
        let start = currentProgress
        guard !UIAccessibility.isReduceMotionEnabled, start != target else {
            setProgress(target)
            completion?()
            return
        }
        let duration = target > start ? 0.32 : 0.20
        let startedAt = CACurrentMediaTime()
        animationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = min(1, (CACurrentMediaTime() - startedAt) / duration)
                let eased = CGFloat(elapsed * elapsed * (3 - 2 * elapsed))
                setProgress(start + (target - start) * eased)
                if elapsed >= 1 {
                    animationTask = nil
                    completion?()
                    return
                }
                do { try await Task.sleep(for: .milliseconds(16)) }
                catch { return }
            }
        }
    }
}
