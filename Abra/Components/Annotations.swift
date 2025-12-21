//
//  Annotations.swift
//  Abra
//

import MapKit
import SwiftUI
import UIKit

// MARK: - Annotation Classes

class ShazamAnnotation: NSObject, MKAnnotation {
    let shazamStream: ShazamStream
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(shazamStream: ShazamStream) {
        self.shazamStream = shazamStream
        self.coordinate = shazamStream.coordinate
        self.title = shazamStream.title
        super.init()
    }
}

class SpotAnnotation: NSObject, MKAnnotation {
    let spot: Spot
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(spot: Spot) {
        self.spot = spot
        self.coordinate = spot.coordinate
        self.title = spot.name
        super.init()
    }
}

// MARK: - Annotation Views

final class ShazamAnnotationView: MKAnnotationView {
    private let imageView = UIImageView()
    private let glassContainerView = UIView()
    private let glassEffectView = UIVisualEffectView()
    private let size: CGFloat = 32
    private let borderWidth: CGFloat = 3

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        collisionMode = .circle

        setupUI()
        loadImage()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet {
            setupUI()
            loadImage()
        }
    }

    private func setupUI() {
        backgroundColor = .clear
        frame = CGRect(x: 0, y: 0, width: size, height: size)

        if #available(iOS 26.0, *) {
            // Create glass container that's slightly larger to show glass border
            glassContainerView.frame = bounds
            glassContainerView.backgroundColor = .clear
            glassContainerView.layer.cornerRadius = 8
            glassContainerView.clipsToBounds = true
            if glassContainerView.superview == nil {
                addSubview(glassContainerView)
            }

            // Use actual UIGlassEffect for true glass appearance
            glassEffectView.effect = UIGlassEffect()
            glassEffectView.frame = glassContainerView.bounds
            glassEffectView.layer.cornerRadius = 8
            glassEffectView.clipsToBounds = true

            if glassEffectView.superview == nil {
                glassContainerView.addSubview(glassEffectView)
            }

            // Image inset slightly to show glass border
            let inset = borderWidth
            imageView.frame = bounds.insetBy(dx: inset, dy: inset)
            imageView.layer.cornerRadius = 6

            // Add inner shadow to image for depth
            imageView.layer.shadowColor = UIColor.black.cgColor
            imageView.layer.shadowOffset = CGSize(width: 0, height: 1)
            imageView.layer.shadowOpacity = 0.3
            imageView.layer.shadowRadius = 2
        } else {
            // iOS 25 and below - use white background
            imageView.frame = bounds
            imageView.layer.cornerRadius = 8
            imageView.backgroundColor = .systemBackground
            imageView.layer.borderColor = UIColor.white.cgColor
            imageView.layer.borderWidth = 2
        }

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear

        if imageView.superview == nil {
            addSubview(imageView)
        }

        // Subtle shadow (spotlight effect)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.masksToBounds = false
    }

    private func loadImage() {
        guard let shazamAnnotation = annotation as? ShazamAnnotation else { return }
        
        imageView.kf.setImage(
            with: shazamAnnotation.shazamStream.artworkURL,
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ]
        )
    }

    // Animate open/close on selection
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        let scale: CGFloat = selected ? 3.0 : 1.0
        let duration: TimeInterval = animated ? 0.5 : 0.0

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.8,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                self.transform = CGAffineTransform(scaleX: scale, y: scale)
            },
            completion: nil
        )
    }
}

final class SpotAnnotationView: MKMarkerAnnotationView {
    static let reuseIdentifier = NSStringFromClass(SpotAnnotation.self)

    override var annotation: MKAnnotation? {
        willSet {
            guard let spotAnnotation = newValue as? SpotAnnotation else { return }
            configure(with: spotAnnotation)
        }
    }

    private func configure(with spotAnnotation: SpotAnnotation) {
        markerTintColor = spotAnnotation.spot.color
        if spotAnnotation.spot.symbol != "" {
            glyphImage = UIImage(systemName: spotAnnotation.spot.symbol)
        }
        displayPriority = .required
    }
}

// MARK: - Cluster View

final class ShazamClusterAnnotationView: MKAnnotationView {
    private let containerView = UIView()
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let countLabel = UILabel()
    private var size: CGFloat = 32

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        displayPriority = .defaultHigh
        collisionMode = .circle

        setupUI()
        updateView()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet {
            updateView()
        }
    }

    private func setupUI() {
        backgroundColor = .clear

        containerView.backgroundColor = .clear
        containerView.frame = bounds
        addSubview(containerView)

        blurEffectView.clipsToBounds = true
        containerView.addSubview(blurEffectView)

        countLabel.textAlignment = .center
        countLabel.font = UIFont.systemFont(ofSize: size / 2, weight: .semibold)
        countLabel.textColor = .label
        countLabel.frame = bounds
        containerView.addSubview(countLabel)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.masksToBounds = false
    }

    private func updateView() {
        guard let cluster = annotation as? MKClusterAnnotation else {
            countLabel.text = ""
            return
        }

        let count = cluster.memberAnnotations.count
        countLabel.text = "\(count)"

        frame = CGRect(origin: frame.origin, size: CGSize(width: size, height: size))
        containerView.frame = bounds
        blurEffectView.frame = bounds
        blurEffectView.layer.cornerRadius = size / 2
        countLabel.frame = bounds
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
