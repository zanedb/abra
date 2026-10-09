//
//  MapViewControllerRepresentable.swift
//  Abra
//

import Combine
import MapKit
import OSLog
import SwiftData
import SwiftUI
import UIKit

/// Bridges the SwiftUI map data into MapKit and hosts the UIKit bottom sheet.
struct MapViewControllerRepresentable: UIViewControllerRepresentable {
    let shazams: [ShazamStream]
    let spots: [Spot]
    let modelContext: ModelContext
    let toast: ToastProvider
    let sheetProvider: SheetProvider
    let shazam: ShazamProvider
    let location: LocationProvider
    let library: LibraryProvider
    let motion: MotionProvider
    let music: MusicProvider

    func makeCoordinator() -> Coordinator {
        Coordinator(
            modelContext: modelContext,
            sheetProvider: sheetProvider
        )
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
            mapView.trailingAnchor.constraint(
                equalTo: mapVC.view.trailingAnchor
            ),
        ])
        context.coordinator.mapView = mapView

        mapView.delegate = context.coordinator
        mapView.showsUserLocation = !MapBenchmarkConfiguration.isEnabled
        mapView.showsUserTrackingButton = !MapBenchmarkConfiguration.isEnabled
        mapView.showsCompass = true
        if let benchmarkRegion = MapBenchmarkConfiguration.mapRegion {
            mapView.setRegion(benchmarkRegion, animated: false)
        } else {
            mapView.setUserTrackingMode(.follow, animated: true)
        }
        mapView.selectableMapFeatures = [.pointsOfInterest]

        mapView.register(
            ShazamAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: NSStringFromClass(
                ShazamAnnotation.self
            )
        )
        mapView.register(
            ShazamClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: NSStringFromClass(
                MKClusterAnnotation.self
            )
        )
        mapView.register(
            SpotAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: NSStringFromClass(
                SpotAnnotation.self
            )
        )

        // Observe SheetProvider.now for selection, centering
        context.coordinator.setupSheetProviderObservation()

        return mapVC
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        context.coordinator.updateDependencies(
            modelContext: modelContext,
            sheetProvider: sheetProvider
        )
        context.coordinator.syncAnnotations(shazams: shazams, spots: spots)

        // Present the bottom sheet, always
        if uiViewController.presentedViewController == nil {
            presentBottomSheet(uiViewController, context: context)
        }
    }

    /// Presents SheetView() as a bottom sheet to the Map's UIViewController.
    private func presentBottomSheet(_ uiVC: UIViewController, context: Context)
    {
        let sheetVC = SheetHostingController(
            rootView: SheetView()
                .environment(\.modelContext, modelContext)
                .environment(\.toastProvider, toast)
                .environment(sheetProvider)
                .environment(shazam)
                .environment(location)
                .environment(library)
                .environment(motion)
                .environment(music)
        )
        sheetVC.sheetLayoutChangeHandler = { presentedFrame in
            guard presentedFrame.height <= 418 else { return }
            let bottomInset = presentedFrame.height - 32  // 64
            context.coordinator.updateLayoutMargins(bottomInset: bottomInset)
        }
        sheetVC.modalPresentationStyle = .custom
        sheetVC.isModalInPresentation = true
        sheetVC.preferredContentSize = CGSize(
            width: 400,
            height: sheetVC.view.frame.height
        )  // TODO: fix this for iPad vibe
        sheetVC.transitioningDelegate = sheetVC
        context.coordinator.bottomSheetVC = sheetVC

        let coordinator = context.coordinator
        sheetProvider.collapseBottomSheet = { [weak sheetVC] in
            guard let sheet = sheetVC?.sheetPresentationController else { return }
            let currentId = sheet.selectedDetentIdentifier
            let isAtLarge = currentId == .largeNoScale
            coordinator.wasAtLargeWhenChildPresented = isAtLarge
            if isAtLarge {
                sheet.animateChanges {
                    sheet.selectedDetentIdentifier = .fraction(0.5)
                }
            }
        }
        sheetProvider.expandBottomSheet = { [weak sheetVC] in
            guard coordinator.wasAtLargeWhenChildPresented,
                  let sheet = sheetVC?.sheetPresentationController else { return }
            sheet.animateChanges {
                sheet.selectedDetentIdentifier = .largeNoScale
            }
            coordinator.wasAtLargeWhenChildPresented = false
        }
        sheetProvider.revealSearchResults = { [weak sheetVC] in
            guard
                let sheet = sheetVC?.sheetPresentationController,
                sheet.selectedDetentIdentifier == .fraction(0.1)
            else { return }

            sheet.animateChanges {
                sheet.selectedDetentIdentifier = .fraction(0.5)
            }
        }

        DispatchQueue.main.async {
            uiVC.present(sheetVC, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        private static let signposter = OSSignposter(
            subsystem: "app.zane.abra",
            category: "MapAnnotations"
        )

        private var modelContext: ModelContext
        private var sheetProvider: SheetProvider
        weak var mapView: MKMapView?
        weak var bottomSheetVC: UIViewController?
        var sheetProviderCancellable: AnyCancellable?
        var isProgrammaticSelection = false
        var lastSelectedAnnotation: MKAnnotation?
        var pendingSpotToSelect: Spot?
        var highlighted: ShazamStream?
        private var temporaryAnnotations: Set<ShazamAnnotation> = []
        private var suppressDidDeselect = false
        private var selectionReconciliationTask: Task<Void, Never>?
        var wasAtLargeWhenChildPresented = false

        // MARK: - Annotation Tracking
        private var shazamAnnotations: [PersistentIdentifier: ShazamAnnotation] = [:]
        private var spotAnnotations: [PersistentIdentifier: SpotAnnotation] = [:]

        init(
            modelContext: ModelContext,
            sheetProvider: SheetProvider
        ) {
            self.modelContext = modelContext
            self.sheetProvider = sheetProvider
        }

        func updateDependencies(
            modelContext: ModelContext,
            sheetProvider: SheetProvider
        ) {
            self.modelContext = modelContext

            guard self.sheetProvider !== sheetProvider else { return }
            self.sheetProvider = sheetProvider
            setupSheetProviderObservation()
        }

        // MARK: - SheetProvider Observation

        func setupSheetProviderObservation() {
            sheetProviderCancellable = sheetProvider.didChange
                .sink { [weak self] in
                    self?.handleSheetProviderChange()
                }
            handleSheetProviderChange()
        }

        private func handleSheetProviderChange() {
            guard bottomSheetVC != nil else { return }

            // Center the map if a valid (non-null-island) coordinate is available
            if let mapView = mapView,
                let coord = sheetProvider.coordinate,
                coord.latitude != 0 || coord.longitude != 0
            {
                // Disable user tracking mode when centering on a selected annotation
                // This prevents the map from snapping back to user location on iOS 26+
                if mapView.userTrackingMode != .none {
                    mapView.setUserTrackingMode(.none, animated: false)
                }

                // Animate if <10km from current center
                let center = CLLocation(
                    latitude: mapView.centerCoordinate.latitude,
                    longitude: mapView.centerCoordinate.longitude
                )
                let animated =
                    center.distance(
                        from: CLLocation(
                            latitude: coord.latitude,
                            longitude: coord.longitude
                        )
                    ) < 10000  // 10km
                mapView.setCenter(coord, animated: animated)

                // Zoom in if the map is too zoomed out (e.g., > 0.1 degrees latitude span)
                let currentSpan = mapView.region.span
                let maxSpanDegrees: CLLocationDegrees = 0.1  // ~11km
                if currentSpan.latitudeDelta > maxSpanDegrees
                    || currentSpan.longitudeDelta > maxSpanDegrees
                {
                    let region = MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.02,
                            longitudeDelta: 0.02
                        )
                    )  // ~2km
                    mapView.setRegion(region, animated: animated)
                }
            }

            // Select annotation
            selectAnnotation()

            // In case the keyboard is open (i.e SheetView search), hide it
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        // MARK: - Annotation Management

        func syncAnnotations(shazams: [ShazamStream], spots: [Spot]) {
            guard let mapView = mapView else { return }

            let signpostID = Self.signposter.makeSignpostID()
            let signpostState = Self.signposter.beginInterval(
                "SyncAnnotations",
                id: signpostID,
                "shazams: \(shazams.count), spots: \(spots.count)"
            )
            var addedCount = 0
            var removedCount = 0
            var updatedCount = 0
            defer {
                Self.signposter.endInterval(
                    "SyncAnnotations",
                    signpostState,
                    "added: \(addedCount), removed: \(removedCount), updated: \(updatedCount)"
                )
            }

            var annotationsToAdd: [MKAnnotation] = []
            annotationsToAdd.reserveCapacity(shazams.count + spots.count)
            var annotationsToRemove: [MKAnnotation] = []

            // Treat every existing annotation as stale until its model appears in
            // this update. This avoids building both old-ID and new-ID sets.
            shazamAnnotations.reserveCapacity(shazams.count)
            var staleShazamIDs = Set(shazamAnnotations.keys)
            for stream in shazams {
                let id = stream.persistentModelID
                staleShazamIDs.remove(id)

                if let annotation = shazamAnnotations[id] {
                    let changes = annotation.update(from: stream)
                    if changes.changed {
                        updatedCount += 1
                    }
                    if changes.artworkChanged {
                        (mapView.view(for: annotation) as? ShazamAnnotationView)?
                            .loadImage()
                    }
                } else {
                    let annotation = ShazamAnnotation(shazamStream: stream)
                    shazamAnnotations[id] = annotation
                    annotationsToAdd.append(annotation)
                    addedCount += 1
                }
            }

            for id in staleShazamIDs {
                if let annotation = shazamAnnotations.removeValue(forKey: id) {
                    annotationsToRemove.append(annotation)
                    removedCount += 1
                }
            }

            spotAnnotations.reserveCapacity(spots.count)
            var staleSpotIDs = Set(spotAnnotations.keys)
            for spot in spots {
                let id = spot.persistentModelID
                staleSpotIDs.remove(id)

                if let annotation = spotAnnotations[id] {
                    let changes = annotation.update(from: spot)
                    if changes.changed {
                        updatedCount += 1
                    }
                    if changes.appearanceChanged {
                        (mapView.view(for: annotation) as? SpotAnnotationView)?
                            .configure(with: annotation)
                    }
                } else {
                    let annotation = SpotAnnotation(spot: spot)
                    spotAnnotations[id] = annotation
                    annotationsToAdd.append(annotation)
                    addedCount += 1
                }
            }

            for id in staleSpotIDs {
                if let annotation = spotAnnotations.removeValue(forKey: id) {
                    annotationsToRemove.append(annotation)
                    removedCount += 1
                }
            }

            let annotationsChanged = !annotationsToRemove.isEmpty
                || !annotationsToAdd.isEmpty
            if annotationsChanged {
                suppressDidDeselect = true
            }

            if !annotationsToRemove.isEmpty {
                mapView.removeAnnotations(annotationsToRemove)
            }
            if !annotationsToAdd.isEmpty {
                mapView.addAnnotations(annotationsToAdd)
            }

            // Handle pending spot selection
            if let spot = pendingSpotToSelect,
                let annotation = spotAnnotations[spot.persistentModelID]
            {
                isProgrammaticSelection = true
                mapView.selectAnnotation(annotation, animated: true)
                lastSelectedAnnotation = annotation
                isProgrammaticSelection = false
                pendingSpotToSelect = nil
            }

            if annotationsChanged {
                reconcileSelectionAfterAnnotationChanges()
            }
        }

        private func reconcileSelectionAfterAnnotationChanges() {
            selectionReconciliationTask?.cancel()
            selectionReconciliationTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }

                guard let self else { return }
                selectAnnotation()
                suppressDidDeselect = false
            }
        }

        private func selectAnnotation() {
            guard let mapView = mapView else { return }
            let now = sheetProvider.now

            var annotationToSelect: MKAnnotation?
            var needsTemporaryAnnotation = false

            switch now {
            case .spot(let spot):
                highlighted = nil
                // Clean up any temporary annotations first
                cleanupTemporaryAnnotations()

                annotationToSelect = spotAnnotations[spot.persistentModelID]

            case .stream(let stream):
                highlighted = stream

                // Direct O(1) lookup
                annotationToSelect = shazamAnnotations[stream.persistentModelID]

                // If not found, we need a temporary annotation
                if annotationToSelect == nil {
                    needsTemporaryAnnotation = true
                } else if findClusterContaining(stream: stream, in: mapView)
                    != nil
                {
                    // Stream exists but is clustered - we need to handle this
                    annotationToSelect = createTemporaryAnnotationFor(
                        stream: stream,
                        in: mapView
                    )
                    needsTemporaryAnnotation = true
                }

            case .none:
                highlighted = nil
                cleanupTemporaryAnnotations()
                annotationToSelect = nil
            }

            // Handle temporary annotation creation
            if needsTemporaryAnnotation,
                let stream = getCurrentStreamFromSheetProvider()
            {
                annotationToSelect = createTemporaryAnnotationFor(
                    stream: stream,
                    in: mapView
                )
            }

            // Select the annotation
            if let annotationToSelect = annotationToSelect,
                mapView.selectedAnnotations.first !== annotationToSelect
            {
                isProgrammaticSelection = true
                mapView.selectAnnotation(annotationToSelect, animated: true)
                lastSelectedAnnotation = annotationToSelect
                isProgrammaticSelection = false
            } else if annotationToSelect == nil {
                isProgrammaticSelection = true
                mapView.selectedAnnotations.forEach {
                    mapView.deselectAnnotation($0, animated: true)
                }
                lastSelectedAnnotation = nil
                isProgrammaticSelection = false
            }
        }

        // MARK: - Helper Methods (NEW)

        private func getCurrentStreamFromSheetProvider() -> ShazamStream? {
            if case .stream(let stream) = sheetProvider.now {
                return stream
            }
            return nil
        }

        private func findClusterContaining(
            stream: ShazamStream,
            in mapView: MKMapView
        ) -> MKClusterAnnotation? {
            return mapView.annotations.compactMap { $0 as? MKClusterAnnotation }
                .first { cluster in
                    if let memberAnnotations = cluster.memberAnnotations
                        as? [ShazamAnnotation]
                    {
                        return memberAnnotations.contains {
                            $0.shazamStream == stream
                        }
                    }
                    return false
                }
        }

        private func createTemporaryAnnotationFor(
            stream: ShazamStream,
            in mapView: MKMapView
        ) -> ShazamAnnotation {
            cleanupTemporaryAnnotations()

            let tempAnnotation = ShazamAnnotation(shazamStream: stream)
            temporaryAnnotations.insert(tempAnnotation)
            mapView.addAnnotation(tempAnnotation)

            return tempAnnotation
        }

        private func cleanupTemporaryAnnotations() {
            guard let mapView = mapView, !temporaryAnnotations.isEmpty else {
                return
            }

            let annotationsToRemove = Array(temporaryAnnotations)
            temporaryAnnotations.removeAll()
            mapView.removeAnnotations(annotationsToRemove)
        }

        private func removeTemporaryAnnotation(_ annotation: ShazamAnnotation) {
            guard let mapView = mapView,
                temporaryAnnotations.contains(annotation)
            else { return }

            temporaryAnnotations.remove(annotation)
            mapView.removeAnnotation(annotation)
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

            let newMargins = NSDirectionalEdgeInsets(
                top: 0,
                leading: leadingInset,
                bottom: bottom,
                trailing: 0
            )
            if mapView.directionalLayoutMargins != newMargins {
                mapView.directionalLayoutMargins = newMargins
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation)
            -> MKAnnotationView?
        {
            switch annotation {
            case let shazam as ShazamAnnotation:
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: NSStringFromClass(ShazamAnnotation.self),
                    for: annotation
                )

                // Handle highlighted streams and temporary annotations
                if shazam.shazamStream == highlighted
                    || temporaryAnnotations.contains(shazam)
                {
                    view.clusteringIdentifier =
                        "UNIQUE_\(shazam.shazamStream.id)"  // unique clustering to prevent clustering
                    view.displayPriority = .required  // always show
                } else {
                    view.clusteringIdentifier = NSStringFromClass(
                        ShazamAnnotation.self
                    )
                    view.displayPriority = .defaultHigh
                }
                return view

            case is SpotAnnotation:
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: NSStringFromClass(SpotAnnotation.self),
                    for: annotation
                )

            case is MKClusterAnnotation:
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: NSStringFromClass(MKClusterAnnotation.self),
                    for: annotation
                )

            default:
                return nil
            }
        }

        func mapView(
            _ mapView: MKMapView,
            didSelect annotation: any MKAnnotation
        ) {
            guard !isProgrammaticSelection else { return }

            switch annotation {
            case let shazamAnnotation as ShazamAnnotation:
                sheetProvider.show(shazamAnnotation.shazamStream)

            case let spotAnnotation as SpotAnnotation:
                sheetProvider.show(spotAnnotation.spot)

            case let clusterAnnotation as MKClusterAnnotation:
                handleClusterSelection(clusterAnnotation, in: mapView)

            case let featureAnnotation as MKMapFeatureAnnotation:
                handleFeatureSelection(featureAnnotation, in: mapView)

            default:
                return
            }

            lastSelectedAnnotation = annotation
        }

        func mapView(
            _ mapView: MKMapView,
            didDeselect annotation: any MKAnnotation
        ) {
            guard !isProgrammaticSelection else { return }

            // Don't dismiss sheet if we're suppressing deselect
            // This prevents the sheet from closing when annotations are removed due to state changes
            guard !suppressDidDeselect else { return }

            // Check if this is a temporary annotation that should be cleaned up after deselection
            let isTemporaryAnnotation =
                (annotation as? ShazamAnnotation).map {
                    temporaryAnnotations.contains($0)
                } ?? false

            switch annotation {
            case is ShazamAnnotation:
                // Only dismiss if this deselection wasn't caused by the stream being assigned to a spot
                if let shazamAnnotation = annotation as? ShazamAnnotation,
                    shazamAnnotation.shazamStream.spot == nil
                {
                    sheetProvider.now = .none
                }

                // Clean up temporary annotation after deselection animation completes
                if isTemporaryAnnotation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        [weak self] in
                        if let shazamAnnotation = annotation
                            as? ShazamAnnotation
                        {
                            self?.removeTemporaryAnnotation(shazamAnnotation)
                        }
                    }
                }

            case is SpotAnnotation:
                sheetProvider.now = .none

            case is MKClusterAnnotation, is MKMapFeatureAnnotation:
                return

            default:
                return
            }

            lastSelectedAnnotation = nil
        }

        // MARK: - Selection Handlers (NEW)

        private func handleClusterSelection(
            _ clusterAnnotation: MKClusterAnnotation,
            in mapView: MKMapView
        ) {
            let currentSpan = mapView.region.span
            let maxSpanDegrees: CLLocationDegrees = 0.1

            if currentSpan.latitudeDelta > maxSpanDegrees
                || currentSpan.longitudeDelta > maxSpanDegrees
            {
                let region = MKCoordinateRegion(
                    center: clusterAnnotation.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: 0.04,
                        longitudeDelta: 0.04
                    )
                )
                mapView.setRegion(region, animated: true)
                mapView.deselectAnnotation(clusterAnnotation, animated: false)
                return
            }

            if let shazamAnnotations = clusterAnnotation.memberAnnotations
                as? [ShazamAnnotation]
            {
                let streams = shazamAnnotations.compactMap(\.shazamStream)
                let spot = Spot(locationFrom: streams.first!)
                modelContext.insert(spot)
                sheetProvider.show(spot)
                mapView.deselectAnnotation(clusterAnnotation, animated: false)
                pendingSpotToSelect = spot

                Task {
                    spot.appendNearbyShazamStreams(modelContext)
                }
            }
        }

        private func handleFeatureSelection(
            _ featureAnnotation: MKMapFeatureAnnotation,
            in mapView: MKMapView
        ) {
            let spot = Spot(from: featureAnnotation)
            modelContext.insert(spot)
            sheetProvider.show(spot)
            mapView.deselectAnnotation(featureAnnotation, animated: false)
            pendingSpotToSelect = spot

            Task {
                spot.appendNearbyShazamStreams(modelContext)
                await spot.affiliateMapItem(from: featureAnnotation)
            }
        }
    }
}

// MARK: - SheetHostingController

class SheetHostingController<Content: View>: UIHostingController<Content>,
    UIViewControllerTransitioningDelegate
{
    var sheetLayoutChangeHandler: ((CGRect) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let sheet = sheetPresentationController
            as? SheetPresentationController
        {
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

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        let controller = SheetPresentationController(
            presentedViewController: presented,
            presenting: presenting
        )
        controller.detents = [
            .fraction(0.1),
            .fraction(0.5),
            .large(allowsScaling: false),
        ]
        if #unavailable(iOS 26.0) {
            controller.preferredCornerRadius = 18
        }
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
        controller.selectedDetentIdentifier = .fraction(0.50)
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
