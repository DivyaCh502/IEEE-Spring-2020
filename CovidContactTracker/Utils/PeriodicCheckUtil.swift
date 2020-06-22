//
//  PeriodicCheckUtil.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import os.log
import RxSwift
import TCNClient
import CoreData
import AppCenterAnalytics

enum TestResult: String {
    case positive = "positive", negative = "negative"
}

// Utility used to periodically check if there are test results and new reports from other users. Main method is `PeriodicCheckUtil.check`
public class PeriodicCheckUtil {
    
    // shared instance
    static let shared = PeriodicCheckUtil()
    
    static var subscription: Disposable? // reference to `PeriodicCheckUtil.check` call
    
    // key storage
    private var keyStore = GenericPasswordStore()
    
    /// the background task ID
    private static var backgroundTaskID: UIBackgroundTaskIdentifier?
    
    private init(){}
    
    // MARK: - Keys
    
    // Do not keep the report authorization key around in memory,
    // since it contains sensitive information.
    // Fetch it every time from our secure store (Keychain).
    private var reportAuthorizationKey: ReportAuthorizationKey {
        do {
            if let storedKey: Curve25519PrivateKey = try keyStore.readKey(account: "tcn-rak") {
                return ReportAuthorizationKey(reportAuthorizationPrivateKey: storedKey)
            }
            else {
                let newKey = Curve25519PrivateKey()
                do {
                    try keyStore.storeKey(newKey, account: "tcn-rak")
                }
                catch {
                    os_log("Storing report authorization key in Keychain failed: %@", log: .app, type: .error, error as CVarArg)
                }
                return ReportAuthorizationKey(reportAuthorizationPrivateKey: newKey)
            }
        }
        catch {
            // Shouldn't get here...
            return ReportAuthorizationKey(reportAuthorizationPrivateKey: Curve25519PrivateKey())
        }
    }
    
    // It is safe to store the temporary contact key in the user defaults,
    // since it does not contain sensitive information.
    private var currentTemporaryContactKey: TemporaryContactKey {
        get {
            if let key = UserDefaults.standard.currentTemporaryContactKey {
                return key
            } else {
                // If there isn't a temporary contact key in the UserDefaults,
                // then use the initial temporary contact key.
                return self.reportAuthorizationKey.initialTemporaryContactKey
            }
        }
        set {
            UserDefaults.standard.currentTemporaryContactKey = newValue
        }
    }
    
    // calculate next key and set to `currentTemporaryContactKey`
    func ratchedKey() -> TCNClient.TemporaryContactNumber {
        let tcNumber = self.currentTemporaryContactKey.temporaryContactNumber
        
        // Ratched the key so, we will get a new temporary contact number the next time
        if let newKey = self.currentTemporaryContactKey.ratchet() {
            self.currentTemporaryContactKey = newKey
        }
        return tcNumber
    }
    
    // MARK: - "Check" methods
    
    /// The main method for checing new data. Returns flag: true - has new data, false - else
    internal static func check() -> Observable<(Bool, UserResponse?)> {
        DispatchQueue.main.async {
            DataSource.logs.append("check: app state: \(UIApplication.shared.applicationState.toString())")
        }
        // check if authenticated
        guard AuthenticationUtil.isAuthenticated() else {
            MSAnalytics.trackEvent("check skipped (not authenticated)")
            DataSource.callback401?()
            return Observable.just((false, nil))
        }
        if let response = AuthenticationUtil.response {
            let isHeadersPresented = !DataSource.headers.isEmpty
            DataSource.logs.append("headers: \(isHeadersPresented ? "HAVE TOKEN" : "EMPTY (now will be filled)")")
            if DataSource.headers.isEmpty {
                AuthenticationUtil.processCredentials(response)
            }
        }
        else {
            DataSource.logs.append("ERROR: user is authenticated, but Auth...response is missing")
        }
        return DataSource.getUser()
            .flatMap({ (user) -> Observable<(Bool, UserResponse?)> in
                MSAnalytics.trackEvent("check in progress (GET /user completed)")
                var tasks = [Observable<Bool>]()
                // If there is a positive result, upload TCN report
                if user.tcnReportRequested ?? false {
                    MSAnalytics.trackEvent("check in progress (generating report)")
                    let report = try! PeriodicCheckUtil.shared.generateReport()
                    tasks.append(DataSource.upload(report: report).map{ return true })
                }
                // If there are new TCN reports from other users, download them and check for exposure
                tasks.append(checkNewReports())
                return Observable.combineLatest(tasks).map { (res) -> (Bool, UserResponse?) in
                    return (res.reduce(true, { x, y in x || y }), user) // if any result is `true`, then return `true`
                }
            })
    }
    
    /// Check new reports
    private static func checkNewReports() -> Observable<Bool> {
        return DataSource.getReports()
            .flatMap({ (reports) -> Observable<Bool> in
                MSAnalytics.trackEvent("check in progress (GET /tcnreports complete)")
                
                // Update records
                return updateInfectedRecords(using: reports).flatMap { (updatedIds) -> Observable<Bool> in
                    
                    // Check exposure
                    return checkExposure(reports, updatedIds: updatedIds)
                        .flatMap({ (infectedByContacts) -> Observable<Bool> in
                            if !infectedByContacts.isEmpty {
                                MSAnalytics.trackEvent("check in progress (sending exposure)")
                                return DataSource.reportExposure(infectedByContacts).map({
                                    return true
                                })
                            }
                            return Observable.just(true)
                        })
                }
            })
    }
    
    /// Updates records in local storage presented in the reports and marks as infected
    private static func updateInfectedRecords(using reports: [SignedReport]) -> Observable<[NSManagedObjectID]> {
        return Observable.create { (obs) -> Disposable in
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            let operations = reports.map { (r: SignedReport) -> UpdateRecordsOperation in
                let operation = UpdateRecordsOperation(context: PersistentContainer.shared.newBackgroundContext(), mergingContexts: [PersistentContainer.shared.viewContext])
                operation.signedReport = r
                return operation
            }
            
            if let lastOperation = operations.last {
                lastOperation.completionBlock = {
//dodo                    let success = !lastOperation.isCancelled
//dodo                if success {UserDefaults.shared.setValue(now, forKey: UserDefaults.Key.lastFetchDate)}
                    var updatedIds = [NSManagedObjectID]()
                    for o in operations {
                        updatedIds.append(contentsOf: o.updatedIds)
                    }
                    obs.onNext(updatedIds); obs.onCompleted()
                }
                
                queue.addOperations(operations, waitUntilFinished: false)
            }
            else {
                obs.onNext([]); obs.onCompleted()
            }
            return Disposables.create {
                queue.cancelAllOperations()
            }
        }
    }
    
    /// Check exposure
    private static func checkExposure(_ reports: [SignedReport], updatedIds: [NSManagedObjectID]) -> Observable<[Contact]> {
        return Observable.create { (obs) -> Disposable in
            if updatedIds.isEmpty {
                obs.onNext([])
                obs.onCompleted()
            }
            else {
                PersistentContainer.shared.loadContacts(byIds: updatedIds) { (list, error) in
                    if let error = error {
                        obs.onError(error)
                    }
                    else {
                        obs.onNext(checkExposure(remote: reports, descovered: list))
                        obs.onCompleted()
                    }
                }
            }
            return Disposables.create()
        }
    }
    
    /// Checks esposure and returns contacts which current user is probably infected by
    private static func checkExposure(remote: [SignedReport], descovered: [TemporaryContactNumber]) -> [Contact] {
        var list = [Contact]()
        let currentUser = (AuthenticationUtil.cognitoId ?? "").data(using: .utf8)!
        for report in remote {
            if report.report.memoData != currentUser { // Skip reports from current user
                if let number = checkExposure(report: report, descovered: descovered) {
                    let c = Contact(tcnReportUser: String(data: report.report.memoData, encoding: .utf8)!,
                                    distance: number.closestEstimatedDistanceMeters as? Float ?? 0,
                                    foundTime: (number.foundDate ?? Date()).timeIntervalSince1970,
                                    lastSeenTime: (number.foundDate ?? Date()).timeIntervalSince1970)
                    list.append(c)
                }
            }
        }
        return list
    }
    
    /// Check esposure and return the contact which probably infected current user
    private static func checkExposure(report: SignedReport, descovered: [TemporaryContactNumber]) -> TemporaryContactNumber? {
        #if DEBUG
        do {
            let res = try report.verify()
            if !res {
                print("ERROR: Invalid report signature:\n\(report.toString())")
            }
        }
        catch let error {
            print(error)
        }
        #endif
        
        
        for number in report.report.getTemporaryContactNumbers() {
//            .filter({!AppDelegate.advertisedTcns.contains($0.bytes)}) { // filter out our own TCNs
            for item in descovered {
                if number.bytes == item.bytes {
                    // dodo distance
                   return item
                }
            }
        }
        return nil
    }
    
    /// Generate report for upload
    func generateReport() throws -> SignedReport {
        // Assuming temporary contact numbers were changed at least every 15 minutes, and the user was infectious in the last 14 days, calculate the start period from the end period.
        let endIndex = currentTemporaryContactKey.index
        let minutesIn14Days = 60 * 24 * 7 * 2
        let periods = minutesIn14Days / 15
        let startIndex: UInt16 = UInt16(max(0, Int(endIndex) - periods))
        
        let tcnSignedReport = try self.reportAuthorizationKey.createSignedReport(
            memoType: .CovidWatchV1,
            memoData: (AuthenticationUtil.cognitoId ?? "").data(using: .utf8)!,
            startIndex: startIndex,
            endIndex: endIndex
        )
        return tcnSignedReport
    }
    
    // MARK: - Public methods
    
    /// Check user
    public static func checkUser(completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        if completionHandler != nil {
            startBackgroundTask()
        }
        if AuthenticationUtil.isAuthenticated() {
            AppDelegate.requestUserNotificationAuthorization()
        }
        MSAnalytics.trackEvent("check (\(completionHandler == nil ? "foreground" : "background"))")
        subscription = PeriodicCheckUtil.check()
            .subscribe(onNext: { (success, user) in
                self.subscription = nil
                if success {
                    completionHandler?(.newData)
                }
                else {
                    completionHandler?(.noData)
                }
                stopBackgroundTask()
                return
            }, onError: { error in
                MSAnalytics.trackEvent("check (\(completionHandler == nil ? "foreground" : "background")) FAILED")
                self.subscription = nil
                completionHandler?(.failed)
                stopBackgroundTask()
                return
            })
    }
    
    /// Start background task
    internal static func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            self.subscription?.dispose()
            self.subscription = nil
            self.stopBackgroundTask()
        }
    }
    
    /// Stop background task
    internal static func stopBackgroundTask() {
        if let id = self.backgroundTaskID, id != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(id)
            self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
    }
     
}

extension UIApplication.State {
    func toString() -> String {
        switch self {
        case .active:
            return "active"
        case .background:
            return "background"
        case .inactive:
            return "inactive"
        }
    }
}
