//
//  AppDelegate.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/1/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit
import TCNClient
import os.log
import CryptoKit
import CoreData
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import SwiftEx
import RxSwift

let USE_NEW_BACKGROUND_TASK_API = false
/**
 <key>BGTaskSchedulerPermittedIdentifiers</key>
 <array>
 <string>com.topcoder.CovidContactTracking.refresh</string>
 <string>com.topcoder.CovidContactTracking.processing</string>
 </array>
 */
let MinimumBackgroundFetchInterval: TimeInterval = Configuration.backgroundFetchInterval

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var tcnBluetoothService: TCNBluetoothService?
    static var isScanning: Bool {
        return UserDefaults.shouldStartBluetooth && wasLaunched
    }
    private var advertisedTcns = [Data]()
    
    // flag: true - the app was already launched, false - else
    private static var wasLaunched = false
    
    // dodo read from storage when opened
    // Used to show last contact date for the user
    static var lastContactTraceDate: Date?
    
    static var deviceToken: String?
    static var tokenRequested = false
    
    var currentUserExposureNotifier: CurrentUserExposureNotifier?
    
    internal var postRequest: Observable<UserPostResponse>?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Requried to update API headers
        if let response = AuthenticationUtil.response, AuthenticationUtil.isAuthenticated() {
            AuthenticationUtil.processCredentials(response)
        }
        
        // For iOS >=13
        if USE_NEW_BACKGROUND_TASK_API { if #available(iOS 13.0, *) {
                PeriodicCheckUtil.registerTasks()
        } }
        else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(MinimumBackgroundFetchInterval)
        }
        
        // For iOS 12 and less
        if #available(iOS 13.0, *) {
        }
        else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(MinimumBackgroundFetchInterval) // iOS 12 or earlier //
        }
        delay(10) {
            print("debug")// e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.topcoder.CovidContactTracking.refresh"]
        }
        let actionsAfterLoading = {
            // dodo clean up
////            UserDefaults.standard.register(defaults: UserDefaults.Key.registration)
            self.configureNotifications()
////            self.configureIsCurrentUserSickObserver()
////            self.signedReportsUploader = SignedReportsUploader()
            self.currentUserExposureNotifier = CurrentUserExposureNotifier() // dodo work incorrectly because updates every time
            self.configureContactTracingService()
//            self.configureIsTemporaryContactNumberLoggingEnabledObserver()
        }
        PersistentContainer.shared.load { error in
            if let error = error {
                let alertController = UIAlertController(title: NSLocalizedString("Error Loading Data", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Delete Data", comment: ""), style: .destructive, handler: { _ in
                    let confirmDeleteController = UIAlertController(title: NSLocalizedString("Confirm", comment: ""), message: nil, preferredStyle: .alert)
                    confirmDeleteController.addAction(UIAlertAction(title: NSLocalizedString("Delete Data", comment: ""), style: .destructive, handler: { _ in
                        PersistentContainer.shared.delete()
                        abort()
                    }))
                    confirmDeleteController.addAction(UIAlertAction(title: NSLocalizedString("Quit", comment: ""), style: .cancel, handler: { _ in
                        abort()
                    }))
                    UIApplication.shared.topViewController?.present(confirmDeleteController, animated: true, completion: nil)
                }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Quit", comment: ""), style: .cancel, handler: { _ in
                    abort()
                }))
                UIApplication.shared.topViewController?.present(alertController, animated: true, completion: nil)
                return
            }
            actionsAfterLoading()
        }
        
        MSAppCenter.start(Configuration.appCenterSecret, withServices:[
            MSAnalytics.self,
            MSCrashes.self
        ])
        return true
    }
    
    static func tryStartTCN() {
        if UserDefaults.shouldStartBluetooth // We don't need to start automatically if user stopped the task
            && !wasLaunched {
            startTCN()
            wasLaunched = true
        }
    }
    
    static func tryStop() {
        if wasLaunched {
            (UIApplication.shared.delegate as! AppDelegate).tcnBluetoothService?.stop()
            wasLaunched = false
        }
    }
    
    /// Start bluetooth service
    static func startTCN() {
        (UIApplication.shared.delegate as! AppDelegate).tcnBluetoothService?.start()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        PersistentContainer.shared.load { (error) in
            guard error == nil else { return }
            guard AuthenticationUtil.isAuthenticated() else { return }
            if #available(iOS 13.0, *) {
                PeriodicCheckUtil.checkUser(task: nil)
            }
            else {
                PeriodicCheckUtil.checkUser(completionHandler: nil)
            }
        }
        AppDelegate.checkNotifcationAuthorizationStillOn()
        AppDelegate.checkBluetoothAuthorizationStillOn()
        NotificationCenter.post(ApplicationEvent.active)
    }
    
    // MARK: - Background tasks
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DataSource.logs.append("perform background fetch")
        AppDelegate.debugShowBackgroundCheckNotification()
        PeriodicCheckUtil.checkUser(completionHandler: completionHandler)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        NotificationCenter.post(ApplicationEvent.resignActive)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save changes in the application's managed object context when the application transitions to the background.
        if PersistentContainer.shared.isLoaded {
            PersistentContainer.shared.saveContext()
        }
        if #available(iOS 13.0, *) {
            if USE_NEW_BACKGROUND_TASK_API && AuthenticationUtil.isAuthenticated() {
                PeriodicCheckUtil.scheduleBackgroundTasks()
            }
        }
        
    }
//
//    // MARK: UISceneSession Lifecycle
//
//    @available(iOS 13.0, *)
//    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
//        // Called when a new scene session is being created.
//        // Use this method to select a configuration to create the new scene with.
//        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
//    }
//
//    @available(iOS 13.0, *)
//    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
//        // Called when the user discards a scene session.
//        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
//        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
//    }
//
    /// Configure service
    func configureContactTracingService() {
        self.tcnBluetoothService =
            TCNBluetoothService(
                tcnGenerator: { () -> Data in
                    
                    let tcNumber = PeriodicCheckUtil.shared.ratchedKey()

                    // dodo read advertisedTcns from storage
                    self.advertisedTcns.append(tcNumber.bytes)
                    if self.advertisedTcns.count > 1024 {
                        self.advertisedTcns.removeFirst()
                    }
                    
                    return tcNumber.bytes
                    
            }, tcnFinder: { (data, estimatedDistance) in
                if !self.advertisedTcns.contains(data) {
                    self.save(with: data, estimatedDistance: estimatedDistance)
                }
            }, errorHandler: { (error) in
                // TODO: Handle errors, like user not giving permission to access Bluetooth, etc.
                ()
            }
        )
    }

    /// Save distance
    private func save(with bytes: Data, estimatedDistance: Double?) {
        print("found: \(bytes) ∆=\(String(describing: estimatedDistance))")
        
        let now = Date()
        // dodo reduce the number findings by 3 seconds. Saves using >500 threads
        
        let context = PersistentContainer.shared.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.perform {
            do {
                let request: NSFetchRequest<TemporaryContactNumber> = TemporaryContactNumber.fetchRequest()
                request.predicate = NSPredicate(format: "bytes == %@", bytes as CVarArg)
                request.fetchLimit = 1
                let results = try context.fetch(request)
                AppDelegate.lastContactTraceDate = now
                var temporaryContactNumber: TemporaryContactNumber! = results.first
                if temporaryContactNumber == nil {
                    temporaryContactNumber = TemporaryContactNumber(context: context)
                    temporaryContactNumber.bytes = bytes
                    temporaryContactNumber.foundDate = now
                }
                temporaryContactNumber.lastSeenDate = now
                if let estimatedDistance = estimatedDistance {
                    let currentEstimatedDistance: Double = temporaryContactNumber.closestEstimatedDistanceMeters?.doubleValue ?? .infinity
                    if estimatedDistance < currentEstimatedDistance {
                        temporaryContactNumber.closestEstimatedDistanceMeters = NSNumber(value: estimatedDistance)
                    }
                }
                try context.save()
                os_log("Logged TCN=%@", log: .app, type: .debug, bytes.base64EncodedString())
            }
            catch {
                os_log("Logging TCN failed: %@", log: .app, type: .error, error as CVarArg)
            }
        }
    }
}


extension UIApplication {
    
    static func openGeneralSettings() {
        // TODO if the app will be rejected, then remove the below code till the commented line and uncomment line with `UIApplication.openSettingsURLString`
        var url: URL!
        if #available(iOS 13.0, *) {
            guard let urlSettings = URL(string: "App-prefs:General") else { return }
            url = urlSettings
        }
        else if #available(iOS 12.0, *) {
            guard let urlSettings = URL(string: "App-prefs:root=General") else { return }
            url = urlSettings
        }
        else if #available(iOS 12.0, *) {
            guard let urlSettings = URL(string: "App-prefs:root=General") else { return }
            url = urlSettings
        }
        else {
            guard let urlSettings = URL(string: "prefs:root=General") else { return }
            url = urlSettings
        }
        //        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        let app = UIApplication.shared
        if app.canOpenURL(url) {
            app.open(url, options: [:], completionHandler: nil)
        }
    }
    
    static func openBluetoothSettings() {
        // TODO if the app will be rejected, then remove the below code till the commented line and uncomment line with `UIApplication.openSettingsURLString`
        var url: URL!
        if #available(iOS 13.0, *) {
            guard let urlSettings = URL(string: "App-prefs:Bluetooth") else { return }
            url = urlSettings
        }
        else if #available(iOS 12.0, *) {
            guard let urlSettings = URL(string: "App-prefs:root=Bluetooth") else { return }
            url = urlSettings
        }
        else {
            guard let urlSettings = URL(string: "prefs:root=Bluetooth") else { return }
            url = urlSettings
        }
        //        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        let app = UIApplication.shared
        if app.canOpenURL(url) {
            app.open(url, options: [:], completionHandler: nil)
        }
    }
    
    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        let app = UIApplication.shared
        if app.canOpenURL(url) {
            app.open(url, options: [:], completionHandler: nil)
        }
    }
}
