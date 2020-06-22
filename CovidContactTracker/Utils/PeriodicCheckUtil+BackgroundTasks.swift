//
//  PeriodicCheckUtil+BgTasks.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import BackgroundTasks
import os.log
import RxSwift
import AppCenterAnalytics

struct BackgroundTaskIdentifiers {
    
    public static let refreshId = "com.topcoder.CovidContactTracking.refresh"
    public static let processingId = "com.topcoder.CovidContactTracking.processing"
}

// This extension is just usage of new API to call `PeriodicCheckUtil.check`.
@available(iOS 13.0, *)
extension PeriodicCheckUtil {
    
    private static let backgroundProcessingTimeout: TimeInterval = 10
    private static var lastOperation: Operation?
    
    public static func registerTasks() {
        let ids: [String] = [
            BackgroundTaskIdentifiers.refreshId,
            BackgroundTaskIdentifiers.processingId
        ]
        ids.forEach { identifier in
            let success = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
                AppDelegate.debugShowBackgroundCheckNotification()
                os_log(
                    "Start background task=%@",
                    log: .app,
                    identifier
                )
                DataSource.logs.append("perform background task")
                self.processBackground(task: task)
            }
            os_log(
                "Register background task=%@ success=%d",
                log: .app,
                type: success ? .default : .error,
                identifier,
                success
            )
        }
    }

    /// Schedule background tasks for fetching and processing data
    public static func scheduleBackgroundTasks() {
//        BGTaskScheduler.shared.cancelAllTaskRequests()
        scheduleRefresh()
//        scheduleProcessing()
    }
    
    /// Check user
    public static func checkUser(task: BGAppRefreshTask?) {
        MSAnalytics.trackEvent("check [iOS 13] (\(task == nil ? "foreground" : "background"))")
        
        if AuthenticationUtil.isAuthenticated() {
            AppDelegate.requestUserNotificationAuthorization()
        }
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let operation = CheckOperation()
        operation.isCalledFromBackground = task != nil
        self.lastOperation = operation
        
        task?.expirationHandler = {
            // After all operations are cancelled, the completion block below is called to set the task to complete.
            queue.cancelAllOperations()
        }
        
        operation.completionBlock = {
            task?.setTaskCompleted(success: !operation.isCancelled)
        }
        
        queue.addOperations([operation], waitUntilFinished: false)
    }
    
    // MARK: -
    
    private static func processBackground(task: BGTask) {
        switch task.identifier {
        case BackgroundTaskIdentifiers.refreshId:
            guard let task = task as? BGAppRefreshTask else { break }
            process(task: task)
//        case BackgroundTaskIdentifiers.processingId:
//            guard let task = task as? BGProcessingTask else { break }
//            process(task: task)
            break
        default:
            task.setTaskCompleted(success: false)
        }
    }
    
    private static func process(task: BGAppRefreshTask) {
        scheduleRefresh()
        checkUser(task: task)
    }
    
//    private func process(task: BGProcessingTask) {
//        self.scheduleProcessing()
//        self.stayAwake(with: task)
//    }
    
    private static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifiers.refreshId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: MinimumBackgroundFetchInterval)
        submitTask(request: request)
    }
    
//    private func scheduleProcessing() {
//        //        let request = BGProcessingTaskRequest(identifier: .processingBackgroundTaskIdentifier)
//        //        request.requiresNetworkConnectivity = false
//        //        request.requiresExternalPower = false
//        //        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
//        //        self.submitTask(request: request)
//    }
    
    private static func submitTask(request: BGTaskRequest) {
        do {
            try BGTaskScheduler.shared.submit(request)
            os_log("Submit task request=%@", log: .app, request.description )
        } catch let error {
            os_log("Submit task request=%@ failed: %@", log: .app, type: .error, request.description, error as CVarArg)
        }
    }
    
    private func stayAwake(with task: BGTask) {
        DispatchQueue.main.asyncAfter(deadline: .now() + PeriodicCheckUtil.backgroundProcessingTimeout) {
            os_log( "End background task=%@", log: .app, task.identifier)
            task.setTaskCompleted(success: true)
        }
    }
}

class CheckOperation: Operation {
    
    private var checking = false
    private var hasData: Bool?
    private var error = false
    var subscription: Disposable? // reference to `PeriodicCheckUtil.check` call
    var isCalledFromBackground = false
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override var isExecuting: Bool {
        return checking
    }
    
    override var isFinished: Bool {
        return hasData != nil
    }
    
    override func cancel() {
        super.cancel()
        if let subscription = subscription {
            subscription.dispose()
            self.subscription = nil
        }
        AppDelegate.debugShowBackgroundCheckNotification(message: "Backgrounf fetch CANCELLED")
    }
    
    func finish(hasData: Bool?, error: Bool) {
        guard checking else { return }
        
        willChangeValue(forKey: #keyPath(isExecuting))
        willChangeValue(forKey: #keyPath(isFinished))
        
        checking = false
        self.hasData = hasData
        self.error = error
        subscription = nil
        
        didChangeValue(forKey: #keyPath(isFinished))
        didChangeValue(forKey: #keyPath(isExecuting))
    }
    
    override func start() {
        willChangeValue(forKey: #keyPath(isExecuting))
        checking = true
        didChangeValue(forKey: #keyPath(isExecuting))
        
        guard !isCancelled else {
            finish(hasData: nil, error: false)
            return
        }
        
        subscription = PeriodicCheckUtil.check()
            .subscribe(onNext: { [weak self] value in
                guard self != nil else { return }
                if self!.isCalledFromBackground {
                    AppDelegate.debugShowBackgroundCheckNotification(message: "Backgrounf fetch COMPLETED")
                }
                guard !self!.isCancelled else { return }
                self?.finish(hasData: value.0, error: false)
                return
            }, onError: { [weak self] error in
                guard self != nil else { return }
                if self!.isCalledFromBackground {
                    AppDelegate.debugShowBackgroundCheckNotification(message: "Backgrounf fetch FAILED")
                }
                MSAnalytics.trackEvent("check [iOS 13] background FAILED")
                guard !self!.isCancelled else { return }
                self?.finish(hasData: false, error: true)
                return
            })
    }
}
