//
//  MapView.swift
//  Abra
//

import Combine
import MapKit
import SwiftData
import SwiftUI
import UIKit

/// MapView also hosts the bottom sheet, using subclassed UISheetPresentationController to track height and update `directionalLayoutMargins` appropriately.
/// Forgive any mess, I'm not a UIKit expert yet ;)

struct MapView: UIViewControllerRepresentable {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.toastProvider) private var toast
    @Environment(SheetProvider.self) private var sheetProvider
    @Environment(ShazamProvider.self) private var shazam
    @Environment(LocationProvider.self) private var location
    @Environment(LibraryProvider.self) private var library
    @Environment(MusicProvider.self) private var music

    @Query(filter: #Predicate<ShazamStream> { $0.spot == nil },
           sort: \ShazamStream.timestamp, order: .reverse)
    private var shazams: [ShazamStream]

    @Query(sort: \Spot.updatedAt, order: .reverse)
    private var spots: [Spot]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let mapVC = UIViewController()
        let mapView = MKMapView(frame: .zero)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapVC.view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: mapVC.view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapVC.view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapVC.view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapVC.view.trailingAnchor)
        ])
        context.coordinator.mapView = mapView

        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsUserTrackingButton = true
        mapView.showsCompass = true
        mapView.setUserTrackingMode(.follow, animated: true)
        mapView.selectableMapFeatures = [.pointsOfInterest]

        mapView.register(ShazamAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(ShazamAnnotation.self))
        mapView.register(ShazamClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(MKClusterAnnotation.self))
        mapView.register(SpotAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(SpotAnnotation.self))

        // Observe SheetProvider.now for selection, centering
        context.coordinator.setupSheetProviderObservation()

        return mapVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.updateAnnotations(shazams: shazams, spots: spots)
        
        // Present the bottom sheet, always
        if uiViewController.presentedViewController == nil {
            presentBottomSheet(uiViewController, context: context)
        }
    }
    
    private func presentBottomSheet(_ uiVC: UIViewController, context: Context) {
        let sheetVC = SheetHostingController(rootView: SheetView()
            .environment(\.modelContext, modelContext)
            .environment(\.toastProvider, toast)
            .environment(sheetProvider)
            .environment(shazam)
            .environment(location)
            .environment(library)
            .environment(music))
        sheetVC.sheetLayoutChangeHandler = { presentedFrame in
            guard presentedFrame.height <= 418 else { return }
            let bottomInset = presentedFrame.height - 64
            context.coordinator.updateLayoutMargins(bottomInset: bottomInset)
        }
        sheetVC.modalPresentationStyle = .custom
        sheetVC.isModalInPresentation = true
        sheetVC.preferredContentSize = CGSize(width: 400, height: sheetVC.view.frame.height) // TODO: fix this for iPad vibe
        sheetVC.transitioningDelegate = sheetVC
        sheetVC.view.backgroundColor = .clear
        context.coordinator.bottomSheetVC = sheetVC

        DispatchQueue.main.async {
            uiVC.present(sheetVC, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        private let parent: MapView
        weak var mapView: MKMapView?
        weak var bottomSheetVC: UIViewController?
        var sheetProviderCancellable: AnyCancellable?
        var isProgrammaticSelection = false
        var lastSelectedAnnotation: MKAnnotation?
        var pendingSpotToSelect: Spot?

        init(_ parent: MapView) {
            self.parent = parent
        }

        // MARK: - SheetProvider Observation

        func setupSheetProviderObservation() {
            sheetProviderCancellable = parent.sheetProvider.didChange
                .sink { [weak self] in
                    self?.handleSheetProviderChange()
                }
            handleSheetProviderChange()
        }

        private func handleSheetProviderChange() {
            guard bottomSheetVC != nil else { return }

            // Center the map if a coordinate is available
            if let mapView = mapView, let coord = parent.sheetProvider.coordinate {
                // Animate if <10km from current center
                let center = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
                let animated = center.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)) < 10000 // 10km
                mapView.setCenter(coord, animated: animated)

                // Zoom in if the map is too zoomed out (e.g., > 0.1 degrees latitude span)
                let currentSpan = mapView.region.span
                let maxSpanDegrees: CLLocationDegrees = 0.1 // ~11km
                if currentSpan.latitudeDelta > maxSpanDegrees || currentSpan.longitudeDelta > maxSpanDegrees {
                    let region = MKCoordinateRegion(center: coord,
                                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)) // ~2km
                    mapView.setRegion(region, animated: animated)
                }
            }

            // Select annotation
            selectAnnotation()

            // In case the keyboard is open (i.e SheetView search), hide it
            parent.hideKeyboard()
        }

        // MARK: - Annotation Management

        func updateAnnotations(shazams: [ShazamStream], spots: [Spot]) {
            guard let mapView = mapView else { return }
            let currentAnnotations = mapView.annotations.filter {
                !($0 is MKUserLocation) && !($0 is MKClusterAnnotation) && !($0 is MKMapFeatureAnnotation)
            }

            let newShazamAnnotations = shazams.map { ShazamAnnotation(shazamStream: $0) }
            let newSpotAnnotations = spots.map { SpotAnnotation(spot: $0) }
            let newAnnotations: [MKAnnotation] = newShazamAnnotations + newSpotAnnotations

            let annotationsToRemove = currentAnnotations.filter { currentAnnotation in
                !newAnnotations.contains { newAnnotation in
                    annotationsAreEqual(currentAnnotation, newAnnotation)
                }
            }

            let annotationsToAdd = newAnnotations.filter { newAnnotation in
                !currentAnnotations.contains { currentAnnotation in
                    annotationsAreEqual(currentAnnotation, newAnnotation)
                }
            }

            if !annotationsToRemove.isEmpty {
                mapView.removeAnnotations(annotationsToRemove)
            }
            if !annotationsToAdd.isEmpty {
                mapView.addAnnotations(annotationsToAdd)
            }

            // After adding annotations, check for pending spot selection
            // This is kinda gross.. but it works #yolo
            if let spot = pendingSpotToSelect {
                if let spotAnnotation = mapView.annotations.first(where: {
                    if let spotAnnotation = $0 as? SpotAnnotation {
                        return spotAnnotation.spot == spot
                    }
                    return false
                }) {
                    isProgrammaticSelection = true
                    mapView.selectAnnotation(spotAnnotation, animated: true)
                    lastSelectedAnnotation = spotAnnotation
                    isProgrammaticSelection = false
                    pendingSpotToSelect = nil // clear the pending spot
                }
            }
            
            // TODO: Check for newly found ShazamStream
        }

        private func annotationsAreEqual(_ lhs: MKAnnotation, _ rhs: MKAnnotation) -> Bool {
            switch (lhs, rhs) {
            case let (shazamL as ShazamAnnotation, shazamR as ShazamAnnotation):
                return shazamL.shazamStream == shazamR.shazamStream
            case let (spotL as SpotAnnotation, spotR as SpotAnnotation):
                return spotL.spot == spotR.spot
            default:
                return false
            }
        }

        private func selectAnnotation() {
            guard let mapView = mapView else { return }
            let now = parent.sheetProvider.now

            // Find the annotation to select
            var annotationToSelect: MKAnnotation?

            switch now {
            case let .spot(spot):
                annotationToSelect = mapView.annotations.first(where: {
                    if let spotAnnotation = $0 as? SpotAnnotation {
                        return spotAnnotation.spot == spot
                    }
                    return false
                })
            case let .stream(stream):
                // If the stream has a spot, select the spot annotation
                if let spot = stream.spot {
                    annotationToSelect = mapView.annotations.first(where: {
                        if let spotAnnotation = $0 as? SpotAnnotation {
                            return spotAnnotation.spot == spot
                        }
                        return false
                    })
                } else {
                    annotationToSelect = mapView.annotations.first(where: {
                        if let shazamAnnotation = $0 as? ShazamAnnotation {
                            return shazamAnnotation.shazamStream == stream
                        }
                        return false
                    })
                }
            case .none:
                annotationToSelect = nil
            }

            // Prevent feedback loop: only select if not already selected
            if let annotationToSelect = annotationToSelect, mapView.selectedAnnotations.first !== annotationToSelect {
                isProgrammaticSelection = true
                mapView.selectAnnotation(annotationToSelect, animated: true)
                lastSelectedAnnotation = annotationToSelect
                isProgrammaticSelection = false
            } else if annotationToSelect == nil {
                // Deselect all if .none
                isProgrammaticSelection = true
                mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: true) }
                lastSelectedAnnotation = nil
                isProgrammaticSelection = false
            }
        }

        // MARK: - Layout Margins

        func updateLayoutMargins(bottomInset: CGFloat) {
            guard let mapView = mapView else { return }
            let idiom = UIDevice.current.userInterfaceIdiom
            let orientation = UIDevice.current.orientation

            var leadingInset: CGFloat = 0
            var bottom = bottomInset

            if (idiom == .phone && orientation.isLandscape) || idiom == .pad {
                leadingInset = 400
                bottom = 0
            }

            let newMargins = NSDirectionalEdgeInsets(top: 0, leading: leadingInset, bottom: bottom, trailing: 0)
            if mapView.directionalLayoutMargins != newMargins {
                mapView.userTrackingMode = .none
                mapView.directionalLayoutMargins = newMargins
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case is ShazamAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(ShazamAnnotation.self), for: annotation)
                view.clusteringIdentifier = NSStringFromClass(ShazamAnnotation.self)
                return view
            case is SpotAnnotation:
                return mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(SpotAnnotation.self), for: annotation)
            case is MKClusterAnnotation:
                return mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(MKClusterAnnotation.self), for: annotation)
            default:
                return nil
            }
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            guard !isProgrammaticSelection else { return }
            switch annotation {
            case let shazamAnnotation as ShazamAnnotation:
                parent.sheetProvider.show(shazamAnnotation.shazamStream)
            case let spotAnnotation as SpotAnnotation:
                parent.sheetProvider.show(spotAnnotation.spot)
            case let clusterAnnotation as MKClusterAnnotation:
                // Zoom in if the map is too zoomed out (e.g., > 0.1 degrees latitude span), don't select
                let currentSpan = mapView.region.span
                let maxSpanDegrees: CLLocationDegrees = 0.1 // ~11km
                if currentSpan.latitudeDelta > maxSpanDegrees || currentSpan.longitudeDelta > maxSpanDegrees {
                    let region = MKCoordinateRegion(center: clusterAnnotation.coordinate,
                                                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)) // ~4km
                    mapView.setRegion(region, animated: true)
                    mapView.deselectAnnotation(clusterAnnotation, animated: false)
                    return
                }
                // Otherwise, create a Spot
                if let shazamAnnotations = clusterAnnotation.memberAnnotations as? [ShazamAnnotation] {
                    let streams = shazamAnnotations.compactMap(\.shazamStream)
                    let spot = Spot(locationFrom: streams.first!, streams: streams)
                    parent.modelContext.insert(spot)
                    parent.sheetProvider.show(spot)
                    // Deselect cluster, select spot
                    mapView.deselectAnnotation(clusterAnnotation, animated: false)
                    pendingSpotToSelect = spot
                    Task {
                        spot.appendNearbyShazamStreams(parent.modelContext)
                    }
                }
            case let featureAnnotation as MKMapFeatureAnnotation:
                let spot = Spot(from: featureAnnotation)
                parent.modelContext.insert(spot)
                parent.sheetProvider.show(spot)
                // Deselect feature, select spot
                mapView.deselectAnnotation(featureAnnotation, animated: false)
                pendingSpotToSelect = spot
                Task {
                    spot.appendNearbyShazamStreams(parent.modelContext)
                    await spot.affiliateMapItem(from: featureAnnotation)
                }
            default:
                return
            }
            lastSelectedAnnotation = annotation
        }

        func mapView(_ mapView: MKMapView, didDeselect annotation: any MKAnnotation) {
            guard !isProgrammaticSelection else { return }
            switch annotation {
            case is ShazamAnnotation, is SpotAnnotation:
                parent.sheetProvider.now = .none
            case is MKClusterAnnotation:
                return
            case is MKMapFeatureAnnotation:
                return
            default:
                return
            }
            lastSelectedAnnotation = nil
        }
    }
}

// MARK: - SheetHostingController

class SheetHostingController<Content: View>: UIHostingController<Content>, UIViewControllerTransitioningDelegate {
    var sheetLayoutChangeHandler: ((CGRect) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let sheet = sheetPresentationController as? SheetPresentationController {
            sheet.layoutChangeHandler = sheetLayoutChangeHandler
        }
    }

    override var sheetPresentationController: UISheetPresentationController? {
        let controller = super.sheetPresentationController
        if let custom = controller as? SheetPresentationController {
            custom.layoutChangeHandler = sheetLayoutChangeHandler
        }
        return controller
    }

    // MARK: UIViewControllerTransitioningDelegate

    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController?
    {
        let controller = SheetPresentationController(presentedViewController: presented, presenting: presenting)
        controller.detents = [
            .small(),
            .fraction(0.5),
            .large(allowsScaling: false)
        ]
        controller.preferredCornerRadius = 18
        controller.prefersEdgeAttachedInCompactHeight = true
        controller.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        controller.prefersScrollingExpandsWhenScrolledToEdge = false
        controller.prefersGrabberVisible = true
        controller.largestUndimmedDetentIdentifier = .fraction(0.5)
        controller.setValue(true, forKey: "tucksIntoUnsafeAreaInCompactHeight")
        controller.setValue(1, forKey: "horizontalAlignment")
        controller.setValue(true, forKey: "wantsBottomAttached")
        controller.setValue(10, forKey: "marginInRegularWidthRegularHeight")
        controller.shouldScaleDownBehindDescendantSheets = false
        controller.layoutChangeHandler = sheetLayoutChangeHandler
        return controller
    }
}

// MARK: - Subclassed UISheetPresentationController

class SheetPresentationController: UISheetPresentationController {
    var layoutChangeHandler: ((CGRect) -> Void)?

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        if let presentedFrame = presentedView?.frame {
            layoutChangeHandler?(presentedFrame)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
