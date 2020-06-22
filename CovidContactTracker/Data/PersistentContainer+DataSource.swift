//
//  PersistentContainer+DataSource.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/7/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation
import CoreData
import TCNClient
import os.log

extension PersistentContainer {
    
    func loadContacts(byIds ids: [NSManagedObjectID], callback: @escaping ([TemporaryContactNumber], Error?)->()) {
        PersistentContainer.shared.load { error in
            if let error = error {
                callback([], error)
                return
            }
            let managedObjectContext = PersistentContainer.shared.viewContext
            let devices = ids.map({managedObjectContext.object(with: $0) as! TemporaryContactNumber})
            callback(devices, nil)
        }
    }
    
    func loadContacts(callback: @escaping (NSFetchedResultsController<TemporaryContactNumber>?, Error?)->()) {
        PersistentContainer.shared.load { error in
            do {
                if let error = error {
                    callback(nil, error)
                    return
                }
                let managedObjectContext = PersistentContainer.shared.viewContext
                let request: NSFetchRequest<TemporaryContactNumber> = TemporaryContactNumber.fetchRequest()
                request.sortDescriptors = [
//                    NSSortDescriptor(keyPath: \TemporaryContactNumber.wasPotentiallyInfectious, ascending: false),
                    NSSortDescriptor(keyPath: \TemporaryContactNumber.lastSeenDate, ascending: false)]
                request.returnsObjectsAsFaults = false
                request.fetchBatchSize = 200
                let fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
                try fetchedResultsController.performFetch()
                
                callback(fetchedResultsController, nil)
            }
            catch let error {
                os_log("Fetched results controller perform fetch failed: %@", log: .app, type: .error, error as CVarArg)
                callback(nil, error)
            }
        }
    }
}
