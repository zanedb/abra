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
    private let size: CGFloat = 36

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        displayPriority = .defaultLow
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
            loadImage()
        }
    }

    private func setupUI() {
        backgroundColor = .clear
        frame = CGRect(x: 0, y: 0, width: size, height: size)

        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = size / 2
        imageView.backgroundColor = .systemBackground

        addSubview(imageView)
    }

    private func loadImage() {
        guard let shazamAnnotation = annotation as? ShazamAnnotation else { return }

        imageView.kf.setImage(
            with: shazamAnnotation.shazamStream.artworkURL,
            placeholder: UIImage(systemName: "exclamationmark.circle.fill"),
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ]
        )
    }
}

final class SpotAnnotationView: MKAnnotationView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let size: CGFloat = 48

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        displayPriority = .defaultHigh
        collisionMode = .circle

        setupUI()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet {
            updateSpotIcon()
        }
    }
    
    private func setupUI() {
        backgroundColor = .clear
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        
        blurView.frame = bounds
        blurView.layer.cornerRadius = size / 2
        blurView.clipsToBounds = true
        addSubview(blurView)

        containerView.frame = bounds
        containerView.layer.cornerRadius = size / 2
        containerView.clipsToBounds = true
        addSubview(containerView)

        let iconSize: CGFloat = size * 0.5 // Icon is 50% of container size
        iconImageView.frame = CGRect(
            x: (size - iconSize) / 2,
            y: (size - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemGray // Will be set in updateSpotIcon()
        containerView.addSubview(iconImageView)

        updateSpotIcon()
    }

    private func updateSpotIcon() {
        guard let spotAnnotation = annotation as? SpotAnnotation else {
            containerView.backgroundColor = .systemGray5
            iconImageView.tintColor = .systemGray
            iconImageView.image = UIImage(systemName: "questionmark")
            return
        }

        containerView.backgroundColor = spotAnnotation.spot.color.withAlphaComponent(0.2)
        iconImageView.tintColor = spotAnnotation.spot.color
        
        let symbol = spotAnnotation.spot.symbol.isEmpty ? "plus.circle.fill" : spotAnnotation.spot.symbol
        let config = UIImage.SymbolConfiguration(
            pointSize: size * 0.4,
            weight: .medium,
            scale: .default
        )
        
        iconImageView.image = UIImage(
            systemName: symbol,
            withConfiguration: config
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        containerView.backgroundColor = .systemGray5
        iconImageView.tintColor = .systemGray
        iconImageView.image = nil
    }
}

// MARK: - Cluster View

final class ShazamClusterAnnotationView: MKAnnotationView {
    private let containerView = UIView()
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let countLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        displayPriority = .defaultHigh
        collisionMode = .circle

        setupUI()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet {
            guard annotation is MKClusterAnnotation else {
//                assertionFailure("Using ShazamClusterAnnotationViewRepresentable with wrong annotation type")
                return
            }

            updateView()
        }
    }

    private func setupUI() {
        backgroundColor = .clear

        containerView.backgroundColor = .clear
        addSubview(containerView)

        blurEffectView.layer.cornerRadius = 20
        blurEffectView.clipsToBounds = true
        containerView.addSubview(blurEffectView)

        countLabel.textAlignment = .center
        countLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textColor = .label
        containerView.addSubview(countLabel)

        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        containerView.frame = bounds
        blurEffectView.frame = bounds
        countLabel.frame = bounds
    }

    private func updateView() {
        guard let cluster = annotation as? MKClusterAnnotation else {
            // Set default state if no cluster annotation yet
            countLabel.text = ""
            return
        }

        let count = cluster.memberAnnotations.count
        countLabel.text = "\(count)"

        // Adjust size based on count
        let size: CGFloat = count > 99 ? 50 : count > 9 ? 45 : 40
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        containerView.frame = bounds
        blurEffectView.frame = bounds
        blurEffectView.layer.cornerRadius = size / 2
        countLabel.frame = bounds
    }
}

#Preview {
    MapView(modelContext: PreviewSampleData.container.mainContext)
        .edgesIgnoringSafeArea(.all)
        .environment(SheetProvider())
        .modelContainer(PreviewSampleData.container)
}
