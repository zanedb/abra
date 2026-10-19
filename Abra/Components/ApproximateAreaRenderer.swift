import MapKit
import UIKit

/// Draws the saved uncertainty area growing from, or shrinking to, its center.
final class ApproximateAreaRenderer: MKOverlayRenderer {
    private let progressLock = NSLock()
    private var progress: CGFloat = 0
    private let fill = UIColor.systemBlue.withAlphaComponent(0.07).cgColor
    private let stroke = UIColor.systemBlue.withAlphaComponent(0.55).cgColor
    private var lastZoomScale: MKZoomScale = 1
    private var displayLink: CADisplayLink?
    private var animationStart: CGFloat = 0
    private var animationTarget: CGFloat = 0
    private var animationStartedAt: CFTimeInterval = 0
    private var animationDuration: CFTimeInterval = 0
    private var animationCompletion: (() -> Void)?

    // CADisplayLink retains its target. A weak proxy lets MapKit release a renderer
    // mid-animation without leaving a display link running indefinitely.
    private final class DisplayLinkTarget: NSObject {
        weak var renderer: ApproximateAreaRenderer?
        @MainActor @objc func tick(_ link: CADisplayLink) {
            guard let renderer else { link.invalidate(); return }
            renderer.advanceAnimation(at: link.targetTimestamp)
        }
    }

    deinit {
        displayLink?.invalidate()
    }

    private var currentProgress: CGFloat {
        progressLock.withLock { progress }
    }

    private func setProgress(_ value: CGFloat) {
        let (previous, zoomScale) = progressLock.withLock {
            let previous = progress
            progress = value
            return (previous, lastZoomScale)
        }
        // Redraw only the union of the old/new circle, including its stroke.
        // Whole-overlay invalidation needlessly redraws the outer area while
        // shrinking, which is especially costly for city-size uncertainty.
        let bounds = overlay.boundingMapRect
        let extent = Double(max(previous, value))
        let dirty = bounds.insetBy(dx: bounds.width * (1 - extent) / 2,
                                  dy: bounds.height * (1 - extent) / 2)
        let strokeMargin = 4 / max(zoomScale, 0.000001)
        setNeedsDisplay(dirty.insetBy(dx: -strokeMargin, dy: -strokeMargin))
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let progress = progressLock.withLock {
            lastZoomScale = zoomScale
            return self.progress
        }
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
        displayLink?.invalidate()
        displayLink = nil
        animationCompletion = nil
        let start = currentProgress
        guard !UIAccessibility.isReduceMotionEnabled, start != target else {
            setProgress(target)
            completion?()
            return
        }
        animationStart = start
        animationTarget = target
        animationDuration = target > start ? 0.32 : 0.20
        animationStartedAt = CACurrentMediaTime()
        animationCompletion = completion
        let proxy = DisplayLinkTarget()
        proxy.renderer = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink = link
        // Common modes keep closing responsive while the map/sheet is being dragged.
        link.add(to: .main, forMode: .common)
    }

    @MainActor
    private func advanceAnimation(at time: CFTimeInterval) {
        let elapsed = max(0, min(1, (time - animationStartedAt) / animationDuration))
        // Smootherstep gives zero velocity AND acceleration at both ends, avoiding
        // the abrupt start/stop of the previous cubic curve without extra duration.
        let eased = CGFloat(elapsed * elapsed * elapsed * (elapsed * (elapsed * 6 - 15) + 10))
        setProgress(animationStart + (animationTarget - animationStart) * eased)
        if elapsed >= 1 {
            displayLink?.invalidate()
            displayLink = nil
            let completion = animationCompletion
            animationCompletion = nil
            completion?()
        }
    }
}
