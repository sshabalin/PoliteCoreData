//
// Copyright (c) 2019 Shakuro (https://shakuro.com/)
//
//

import Foundation
import UIKit
import CoreData

public enum FetchedResultsControllerChangeType {
    case insert(indexPath: IndexPath)
    case delete(indexPath: IndexPath)
    case move(indexPath: IndexPath, newIndexPath: IndexPath)
    case update(indexPath: IndexPath)

    case insertSection(index: Int)
    case deleteSection(index: Int)
}

/// Wrapper on NSFetchedResultsController, provides easy way to observe collection of entities.
/// See also: [SingleObjectFetchedResultController](x-source-tag://SingleObjectFetchedResultController)
/// - Tag: FetchedResultsController
public final class FetchedResultsController<EntityType, ResultType: ManagedEntity>: NSObject where ResultType.EntityType == EntityType {

    /**
     Notifies that section and object changes are about to be processed and notifications will be sent.
     Is equivalent to NSFetchedResultsControllerDelegate controllerWillChangeContent
     */
    public var willChangeContent: ((_ controller: FetchedResultsController<EntityType, ResultType>) -> Void)?

    /**
     Notifies that all section and object changes have been sent.
     Is equivalent to NSFetchedResultsControllerDelegate controllerDidChangeContent
     */
    public var didChangeContent: ((_ controller: FetchedResultsController<EntityType, ResultType>) -> Void)?

    /**
     Notifies about particular changes such as add, remove, move, or update.
     */
    public var didChangeFetchedResults: ((_ controller: FetchedResultsController<EntityType, ResultType>, _ type: FetchedResultsControllerChangeType) -> Void)?

    /**
     Wrapped NSFetchedResultsController
     */
    public let fetchedResultsController: NSFetchedResultsController<EntityType>

    private let delegateProxy = HiddenDelegateProxy<EntityType, ResultType>()

    public init(fetchedResultsController: NSFetchedResultsController<EntityType>) {
        self.fetchedResultsController = fetchedResultsController
        super.init()
        delegateProxy.target = self
        fetchedResultsController.delegate = delegateProxy
    }

    /// Sets new sort descriptors. Call performFetch() to apply
    ///
    /// - Parameters:
    ///   - term: An array of sort keys
    ///   - shouldPerformFetch: Pass true to perform fetch at the end of the method execution
    public func setSortDescriptors(_ sortDescriptors: [NSSortDescriptor], shouldPerformFetch: Bool) {
        guard !sortDescriptors.isEmpty else {
            assertionFailure("FetchedResultsController.setSortTerm SortTerm can't be empty!")
            return
        }
        fetchedResultsController.fetchRequest.sortDescriptors = sortDescriptors
        if shouldPerformFetch {
            do {
                try performFetch()
            } catch let error {
                assertionFailure("\(type(of: self)) - \(#function): . \(error)")
            }
        }
    }

    /// Calls performFetch() method of NSFetchedResultsController
    ///
    /// - Throws: An error in cases of failure.
    public func performFetch() throws {
        try fetchedResultsController.performFetch()
    }

    /// Sets new predicate, deletes cache and calls performFetch() method of NSFetchedResultsController
    ///
    /// - Parameter predicate: New predicate for using in fetch request
    /// - Throws: An error in cases of failure.
    public func performFetch(predicate: NSPredicate) throws {
        if let cacheName = fetchedResultsController.cacheName {
            NSFetchedResultsController<EntityType>.deleteCache(withName: cacheName)
        }
        fetchedResultsController.fetchRequest.predicate = predicate
        try performFetch()
    }

    /// Computes total number of items across all sections
    ///
    /// - Returns: The total number of items
    public func totalNumberOfItems() -> Int {
        return fetchedResultsController.sections?.reduce(0, {$0 + $1.numberOfObjects}) ?? 0
    }

    ///
    /// - Parameter index: An index of requested section
    /// - Returns: The number of items in section with specified index
    public func numberOfItemsInSection(_ index: Int) -> Int {
        return fetchedResultsController.sections?[index].numberOfObjects ?? 0
    }

    ///
    /// - Returns: Number of sections
    public func numberOfSections() -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    ///
    /// - Parameter indexPath: An index path in the fetch results.
    /// - Returns: The fetched entity at a given indexPath.
    /// - Tag: funcItemAtIndexPathTyped
    public func itemAtIndexPath(_ indexPath: IndexPath) -> ResultType {
        return ResultType(entity: fetchedResultsController.object(at: indexPath))
    }

    /// Generic version of [func itemAtIndexPath(_ indexPath: IndexPath) -> ResultType](x-source-tag://funcItemAtIndexPathTyped)
    /// - Parameter indexPath: An index path in the fetch results.
    /// - Returns: The fetched entity at a given indexPath.
   public func itemAtIndexPath<T: ManagedEntity>(_ indexPath: IndexPath) -> T? {
        if let cdItem = fetchedResultsController.object(at: indexPath) as? T.EntityType {
            return T(entity: cdItem)
        } else {
            return nil
        }
    }

    /// Returns the IndexPath for the specified entity or nil if the entity does not exist.
    ///
    /// - Parameter entity: The entity for the requested IndexPath.
    /// - Returns: The IndexPath for the specified entity or nil
    public func indexPath(entity: ResultType) -> IndexPath? {
        guard let object: EntityType = (try? fetchedResultsController.managedObjectContext.existingObject(with: entity.objectID)) as? EntityType else {
            return nil
        }
        return fetchedResultsController.indexPath(forObject: object)
    }

    /// Returns an entity for the specified URI representation of an object ID or nil if the object does not exist.
    ///
    /// - Parameter url: The URI representation of an object ID
    /// - Returns: An entity specified by URL or nil.
    public func itemWithURL(_ url: URL) -> ResultType? {
        guard let objectID = fetchedResultsController.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
            let object: EntityType = (try? fetchedResultsController.managedObjectContext.existingObject(with: objectID)) as? EntityType else {
                return nil
        }
        return ResultType(entity: object)
    }

    /// Calls the given closure on each element in the section specified by index.
    ///
    /// - Parameters:
    ///   - section: The section index
    ///   - body: A closure that takes an entity and index path from the section as a parameters.
    public func forEach(inSection section: Int, body: (IndexPath, ResultType) -> Bool) {
        let numberOfObjects = numberOfItemsInSection(section)
        for row in 0..<numberOfObjects {
            let path = IndexPath(row: row, section: section)
            let shouldContinue = body(path, itemAtIndexPath(path))
            if !shouldContinue {
                break
            }
        }
    }

}

// MARK: - Private NSFetchedResultsControllerDelegate

private final class HiddenDelegateProxy<EntityType, ResultType: ManagedEntity>: NSObject, NSFetchedResultsControllerDelegate where ResultType.EntityType == EntityType {

    weak var target: FetchedResultsController<EntityType, ResultType>?

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        guard let actualTarget = target else {
            return
        }
        switch type {
        case .insert:
            if let actualPath: IndexPath = newIndexPath {
                actualTarget.didChangeFetchedResults?(actualTarget, .insert(indexPath: actualPath))
            }
        case .delete:
            if let actualPath: IndexPath = indexPath {
                actualTarget.didChangeFetchedResults?(actualTarget, .delete(indexPath: actualPath))
            }
        case .move:
            if let actualPath: IndexPath = indexPath,
                let actualNewIndexPath: IndexPath = newIndexPath {
                if actualPath != actualNewIndexPath {
                    actualTarget.didChangeFetchedResults?(actualTarget, .move(indexPath: actualPath, newIndexPath: actualNewIndexPath))
                } else {
                    actualTarget.didChangeFetchedResults?(actualTarget, .update(indexPath: actualNewIndexPath))
                }
            }
        case .update:
            if let actualPath: IndexPath = indexPath {
                actualTarget.didChangeFetchedResults?(actualTarget, .update(indexPath: actualPath))
            }
        @unknown default:
            break
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange sectionInfo: NSFetchedResultsSectionInfo,
                    atSectionIndex sectionIndex: Int,
                    for type: NSFetchedResultsChangeType) {
        guard let actualTarget = target else {
            return
        }
        switch type {
        case .insert:
            actualTarget.didChangeFetchedResults?(actualTarget, .insertSection(index: sectionIndex))
        case .delete:
            actualTarget.didChangeFetchedResults?(actualTarget, .deleteSection(index: sectionIndex))
        default:
            break
        }
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let actualTarget = target else {
            return
        }
        actualTarget.willChangeContent?(actualTarget)
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let actualTarget = target else {
            return
        }
        actualTarget.didChangeContent?(actualTarget)
    }

}
