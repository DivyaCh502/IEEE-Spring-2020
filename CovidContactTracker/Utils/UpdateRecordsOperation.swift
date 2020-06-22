//
//  UpdateRecordsOperation.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/7/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation
import CoreData
import TCNClient
import os.log

/// Operation that marks TCN records with `wasPotentiallyInfectious:=true`
class UpdateRecordsOperation: Operation {
    
    var signedReport: SignedReport?
    private let context: NSManagedObjectContext
    private let mergingContexts: [NSManagedObjectContext]?
    private var processing = false
    private var finishedUpdate = false
    
    /// the IDs of the updated TCN. They should be used to send POST /user/report and for notification (if not empty list, then notify about the infection).
    var updatedIds = [NSManagedObjectID]()
    
    init(context: NSManagedObjectContext, mergingContexts: [NSManagedObjectContext]? = nil) {
        self.context = context
        self.mergingContexts = mergingContexts
        super.init()
    }
    
    override var isExecuting: Bool {
        return processing
    }
    
    override var isFinished: Bool {
        return finishedUpdate
    }
    
    override func start() {
        willChangeValue(forKey: #keyPath(isExecuting))
        processing = true
        didChangeValue(forKey: #keyPath(isExecuting))
        
        guard let signedReport = self.signedReport, !isCancelled else {
            finish()
            return
        }
        updateRecordsAsInfected(signedReport: signedReport, context: context, mergingContexts: mergingContexts)
    }
    
    func finish() {
        guard processing else { return }
        
        willChangeValue(forKey: #keyPath(isExecuting))
        willChangeValue(forKey: #keyPath(isFinished))
        
        processing = false
        finishedUpdate = true
        
        didChangeValue(forKey: #keyPath(isFinished))
        didChangeValue(forKey: #keyPath(isExecuting))
    }
    
    func updateRecordsAsInfected(signedReport: SignedReport, context: NSManagedObjectContext, mergingContexts: [NSManagedObjectContext]? = nil) {
        context.performAndWait {
            do {
                // Long-running operation
                let recomputedTemporaryContactNumbers = signedReport.report.getTemporaryContactNumbers()
                
                guard !self.isCancelled else {
                    os_log("updateRecordsAsInfected interrupted", log: .app)
                    return
                }
                
                let identifiers: [Data] = recomputedTemporaryContactNumbers.compactMap({ $0.bytes })
                
                os_log("Marking %d temporary contact numbers(s) as potentially infectious=%d ...", log: .app, identifiers.count, true)
                
                var allUpdatedObjectIDs = [NSManagedObjectID]()
                try identifiers.chunked(into: 300000).forEach { (identifiers) in
                    guard !self.isCancelled else {
                        os_log("updateRecordsAsInfected interrupted", log: .app)
                        return
                    }
                    let batchUpdateRequest = NSBatchUpdateRequest(entity: TemporaryContactNumber.entity())

                    let c = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "bytes IN %@", identifiers, true),
                        NSPredicate(format: "wasPotentiallyInfectious == 0"),
                    ])
                    batchUpdateRequest.predicate = c
                    batchUpdateRequest.resultType = .updatedObjectIDsResultType
                    batchUpdateRequest.propertiesToUpdate = [
                        "wasPotentiallyInfectious" : true,
                    ]
                    let batchUpdateResult = try context.execute(batchUpdateRequest) as! NSBatchUpdateResult
                    let updatedObjectIDs = batchUpdateResult.result as! [NSManagedObjectID]
                    allUpdatedObjectIDs.append(contentsOf: updatedObjectIDs)
                }
                
                if !allUpdatedObjectIDs.isEmpty, let mergingContexts = mergingContexts {
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSUpdatedObjectsKey: allUpdatedObjectIDs], into: mergingContexts)
                }
                self.updatedIds = allUpdatedObjectIDs
                os_log("Marked %d temporary contact number(s) as potentially infectious=%d", log: .app, identifiers.count, true)
                finish()
            }
            catch {
                os_log("FAILED: Marking temporary contact number(s) as potentially infectious=%d failed: %@", log: .app, type: .error, true, error as CVarArg)
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
