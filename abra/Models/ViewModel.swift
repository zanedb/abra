//
//  ViewModel.swift
//  abra
//
//  Created by Zane on 7/6/23.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import MapKit
import ShazamKit

@MainActor final class ViewModel: ObservableObject {
    private let list: FetchedResultList<SStream>
    private let placesList: FetchedResultList<Place>
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        list = FetchedResultList(context: context,
                                 sortDescriptors: [
                                    NSSortDescriptor(keyPath: \SStream.timestamp, ascending: false)
                                 ])
        
        placesList = FetchedResultList(context: context,
                                       sortDescriptors: [
                                        NSSortDescriptor(keyPath: \Place.updatedAt, ascending: false)
                                       ])
        
        list.willChange = { [weak self] in self?.objectWillChange.send() }
        placesList.willChange = { [weak self] in self?.objectWillChange.send() }
        
        // there's gotta be a better way
        list.addAnnotation = { annotation in self.addAnnotation?(annotation) }
        list.removeAnnotation = { annotation in self.removeAnnotation?(annotation) }
        list.updateAnnotation = { annotation in self.updateAnnotation?(annotation) }
    }
    
    var streams: [SStream] {
        list.items
    }
    
    var places: [Place] {
        placesList.items
    }
    
    @Published var searchText: String = "" {
        didSet {
            list.predicate = searchText.isEmpty
                ? nil
                : NSPredicate(format: "trackTitle contains[cd] %@", searchText)
        }
    }
    
    @Published var center: CLLocationCoordinate2D = MapDefaults.coordinate
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(center: MapDefaults.coordinate, span: MapDefaults.span)
    @Published var userTrackingMode: MKUserTrackingMode = .none
    @Published var selectedDetent: PresentationDetent = PresentationDetent.fraction(0.5)
    @Published var detentHeight: CGFloat = 0
    
    @Published var newPlaceSheetShown: Bool = false
    @Published var newPlaceCoordinate: CLLocationCoordinate2D = MapDefaults.coordinate
    @Published var newPlaceRegion: MKCoordinateRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3316876, longitude: -122.0327261), span: MKCoordinateSpan(latitudeDelta: 0.00125, longitudeDelta: 0.00125))
    @Published var currentSongs: [SStream] = []
    @Published var currentSongsCount: Int = 0
    
    @ObservedObject var shazam = Shazam()
    
    // TODO: create a function that returns annotations/SStreams within _ range of _ center
    
    func newPlace(_ songs: [MKAnnotation], _ coord: CLLocationCoordinate2D) {
        if let downcast = songs as? [SStream] {
            currentSongs = downcast
            currentSongsCount = downcast.count
            newPlaceCoordinate = coord
            newPlaceRegion = MKCoordinateRegion(center: newPlaceCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.00125, longitudeDelta: 0.00125))
            newPlaceSheetShown = true
        }
    }
    
    func createPlace(name: String, radius: Double, symbol: String, context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        let newPlace = Place(context: context)
        
        newPlace.name = name
        newPlace.radius = radius
        newPlace.iconName = symbol
        
        newPlace.latitude = newPlaceCoordinate.latitude
        newPlace.longitude = newPlaceCoordinate.longitude
        
        // TODO: store songs inside of newPlace thru some kind of relational magic
        
//        newPlace.city = //
//        newPlace.country = //
//        newPlace.countryCode = //
//        newPlace.state = //
        
        newPlace.createdAt = Date()
        newPlace.updatedAt = Date()
        
        do {
            try context.save()
            newPlaceSheetShown = false
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    // MARK: this is called when a song/place is tapped, moves the map to it
    func updateCenter(_ latitude: CLLocationDegrees, _ longitude: CLLocationDegrees) {
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        center = coord
    }
    
    var addAnnotation: ((_ annotation: Any) -> Void)?
    var updateAnnotation: ((_ annotation: Any) -> Void)?
    var removeAnnotation: ((_ annotation: Any) -> Void)?
    
    var centerCancellable: AnyCancellable?
    var detentCancellable: AnyCancellable?
    var locateUserButtonCancellable: AnyCancellable?
}

// based on https://augmentedcode.io/2023/04/03/nsfetchedresultscontroller-wrapper-for-swiftui-view-models/
@MainActor final class FetchedResultList<Result: NSManagedObject> {
    private let fetchedResultsController: NSFetchedResultsController<Result>
    private let observer: FetchedResultsObserver<Result>
    
    init(context: NSManagedObjectContext, filter: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]) {
        let request = NSFetchRequest<Result>(entityName: Result.entity().name ?? "<not set>")
        request.predicate = filter
        request.sortDescriptors = sortDescriptors.isEmpty ? nil : sortDescriptors
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        
        observer = FetchedResultsObserver(controller: fetchedResultsController)
        observer.willChange = { [unowned self] in self.willChange?() }
        
        observer.didChange = { [unowned self] in self.didChange?() }
        
        observer.addAnnotation = { annotation in self.addAnnotation?(annotation) }
        observer.removeAnnotation = { annotation in self.removeAnnotation?(annotation) }
        observer.updateAnnotation = { annotation in self.updateAnnotation?(annotation) }
        
        refresh()
    }
    
    private func refresh() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Failed to load results")
        }
    }
    
    var items: [Result] {
        fetchedResultsController.fetchedObjects ?? []
    }
    
    var predicate: NSPredicate? {
        get {
            fetchedResultsController.fetchRequest.predicate
        } set {
            fetchedResultsController.fetchRequest.predicate = newValue
            refresh()
        }
    }
    
    var sortDescriptors: [NSSortDescriptor] {
        get {
            fetchedResultsController.fetchRequest.sortDescriptors ?? []
        } set {
            fetchedResultsController.fetchRequest.sortDescriptors = newValue.isEmpty ? nil : newValue
            refresh()
        }
    }
    
    var willChange: (() -> Void)?
    var didChange: (() -> Void)?
    
    var addAnnotation: ((_ annotation: Any) -> Void)?
    var removeAnnotation: ((_ annotation: Any) -> Void)?
    var updateAnnotation: ((_ annotation: Any) -> Void)?
}

private final class FetchedResultsObserver<Result: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate {
    var willChange: () -> Void = {}
    var didChange: () -> Void = {}
    
    var addAnnotation: ((_ annotation: Any) -> Void) = {annotation in }
    var removeAnnotation: ((_ annotation: Any) -> Void) = {annotation in }
    var updateAnnotation: ((_ annotation: Any) -> Void) = {annotation in }
        
    init(controller: NSFetchedResultsController<Result>) {
        super.init()
        controller.delegate = self
    }
        
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        willChange()
    }
        
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        didChange()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for changeType: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        let types = [SStream.self, Place.self]
        
        guard types.contains(where: { $0 == type(of: anObject) }) else {
            preconditionFailure("All changes observed in the view controller should be for SStream or Place instances")
        }
        
        switch changeType {
        case .insert:
            print("add annotation event fired for", (anObject as? SStream)?.trackTitle ?? (anObject as? Place)?.name ?? "missing title")
            addAnnotation(anObject)

        case .delete:
            print("remove annotation event fired for", (anObject as? SStream)?.trackTitle ?? (anObject as? Place)?.name ?? "missing title")
            removeAnnotation(anObject)

        case .update:
            print("update annotation event fired for", (anObject as? SStream)?.trackTitle ?? (anObject as? Place)?.name ?? "missing title")
            updateAnnotation(anObject)

        case .move:
            // N.B. The fetched results controller was set up with a single sort descriptor that produced a consistent ordering for its fetched Point instances.
            fatalError("How did we move a SStream/Place? We should have a stable sort.")
        @unknown default:
            fatalError("Unsupported NSFetchedResultsChangeType")
        }
    }
}
