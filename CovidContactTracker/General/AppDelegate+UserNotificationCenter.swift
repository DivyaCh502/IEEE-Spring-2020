//
//  Created by Zsombor SZABO on 20/09/2017.
//

import UserNotifications
import UIKit
import os.log
import CoreBluetooth
import RxSwift
import SwiftEx

extension UNNotificationCategory {
    
    public static let currentUserExposed = "currentUserExposed"
    public static let openApp = "openApp"
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // MARK: User Notification Center
    
    static func requestUserNotificationAuthorization(provisional: Bool = false) {
        let options: UNAuthorizationOptions = provisional ? [.alert, .sound, .badge, .providesAppNotificationSettings, .provisional] : [.alert, .sound, .badge, .providesAppNotificationSettings]
        UNUserNotificationCenter.current().requestAuthorization(options: options, completionHandler: { (granted, error) in
            DispatchQueue.main.async {
                if let error = error, UIApplication.shared.applicationState == .active {
                    UIApplication.shared.topViewController?.present(error as NSError, animated: true)
                    return
                }
                if granted {
                    scheduleReminderNotification()
                    if UIApplication.shared.applicationState == .active && !AppDelegate.tokenRequested {
                        AppDelegate.deviceToken = nil
                        AppDelegate.tokenRequested = true
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        })
    }
    
    static func checkNotifcationAuthorizationStillOn(provisional: Bool = false) {
        guard AuthenticationUtil.isAuthenticated() else { return }
        let options: UNAuthorizationOptions = provisional ? [.alert, .sound, .badge, .providesAppNotificationSettings, .provisional] : [.alert, .sound, .badge, .providesAppNotificationSettings]
        UNUserNotificationCenter.current().requestAuthorization(options: options, completionHandler: { (granted, error) in
            DispatchQueue.main.async {
                if !granted {
                    // Show warning
                    showNotificationsWarning()
                }
            }
        })
    }
    
    private static func showNotificationsWarning() {
        let vc = UIAlertController(title: NSLocalizedString("Turn on Notifications", comment: ""), message: "Notifications are turned off. Please turn them on in Settings app", preferredStyle: .alert)
        vc.addAction(UIAlertAction(title: NSLocalizedString("Open Settings App", comment: ""), style: .default, handler: { _ in
            UIApplication.openAppSettings()
        }))
        vc.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { _ in
        }))
        UIApplication.shared.topViewController?.present(vc, animated: true, completion: nil)
    }
    
    static func checkBluetoothAuthorizationStillOn() {
        guard AuthenticationUtil.isAuthenticated() else { return }
        var state: CBAuthState!
        if #available(iOS 13.1, *) {
            state = CBManager.authorization.toState()
        } else {
            state = CBPeripheralManager.authorizationStatus().toState()
        }
        if state == CBAuthState.denied {
            showBluetoothWarning()
        }
    }
    
    private static func showBluetoothWarning() {
        let vc = UIAlertController(title: NSLocalizedString("Turn on Bluetooth permissions", comment: ""), message: "Turn on Bluetooth permissions for HutchTrace in Settings", preferredStyle: .alert)
        vc.addAction(UIAlertAction(title: NSLocalizedString("Open Settings App", comment: ""), style: .default, handler: { _ in
            UIApplication.openAppSettings()
        }))
        vc.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { _ in
        }))
        UIApplication.shared.topViewController?.present(vc, animated: true, completion: nil)
    }
    
    func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        // Exposed: Message, View
        let currentUserExposedCategory = UNNotificationCategory(
            identifier: UNNotificationCategory.currentUserExposed,
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: NSLocalizedString("Exposed", comment: ""),
            categorySummaryFormat: nil,
            options: [])
        let openAppCategory = UNNotificationCategory(
            identifier: UNNotificationCategory.openApp,
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: NSLocalizedString("Keep open", comment: ""),
            categorySummaryFormat: nil,
            options: [])
        center.setNotificationCategories([currentUserExposedCategory, openAppCategory])
        center.delegate = self
    }
    
    /// Show "Exposed" notification
    public func showCurrentUserExposedUserNotification() {
        let nc = UNMutableNotificationContent()
        nc.categoryIdentifier = UNNotificationCategory.currentUserExposed
        nc.sound = .defaultCritical
        // When exporting for localizations Xcode doesn't look for NSString.localizedUserNotificationString(forKey:, arguments:))
        _ = NSLocalizedString("You have been possibly exposed to someone who you have recently been in contact with, and who has subsequently self-reported as having the virus.", comment: "")
        nc.body = NSString.localizedUserNotificationString(forKey: "You have been possibly exposed to someone who you have recently been in contact with, and who has subsequently self-reported as having the virus.", arguments: nil)
        let r = UNNotificationRequest(identifier: UNNotificationCategory.currentUserExposed,
                                      content: nc,
                                      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false))
        AppDelegate.scheduleNotification(r)
    }
    
    // Show debug notification
    // dodo !!!!!!!!!!!!!
    public static func debugShowBackgroundCheckNotification(message: String = "Background check is invoked") {
//        let nc = UNMutableNotificationContent()
//        nc.categoryIdentifier = UNNotificationCategory.currentUserExposed
//        nc.sound = .default
//        _ = NSLocalizedString(message, comment: "")
//        nc.body = NSString.localizedUserNotificationString(forKey: message, arguments: nil)
//        let r = UNNotificationRequest(identifier: UNNotificationCategory.currentUserExposed,
//                                      content: nc,
//                                      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false))
//        AppDelegate.scheduleNotification(r)
    }
    
    // MARK: - Reminder
    
    private static func scheduleReminderNotification() {
        // 1-4 days
        let now = Date()
        for i in 1...4 {
            let date = now.add(days: i)
            var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            // Use configured HOUR and MINUTE if non-negative
            if Configuration.reminderNotificationHour >= 0 {
                dateComponents.hour = Configuration.reminderNotificationHour
            }
            if Configuration.reminderNotificationMinute >= 0 {
                dateComponents.minute = Configuration.reminderNotificationMinute
            }
            scheduleReminderNotification(dateComponents: dateComponents, index: i, repeats: false)
        }
        
        // Configure the recurring date.
        /// Day 5, then 5+1 week, etc.
        let dayIndex = 5
        let date = now.add(days: dayIndex)
        var dateComponents = Calendar.current.dateComponents([.weekday, .hour, .minute], from: date)
        if Configuration.reminderNotificationHour >= 0 {
            dateComponents.hour = Configuration.reminderNotificationHour
        }
        if Configuration.reminderNotificationMinute >= 0 {
            dateComponents.minute = Configuration.reminderNotificationMinute
        }
        scheduleReminderNotification(dateComponents: dateComponents, index: dayIndex, repeats: true)
    }
    
    private static func scheduleReminderNotification(dateComponents: DateComponents, index: Int, repeats: Bool) {
        // Create the trigger as a repeating event.
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        
        let nc = UNMutableNotificationContent()
        nc.categoryIdentifier = UNNotificationCategory.openApp
        nc.sound = .default
        // When exporting for localizations Xcode doesn't look for NSString.localizedUserNotificationString(forKey:, arguments:))
        _ = NSLocalizedString("The HutchTrace app must be up and running in order to successfully collect proximity trace data. Click here to start the app. Thank you for your participation.", comment: "")
        nc.body = NSString.localizedUserNotificationString(forKey: "The HutchTrace app must be up and running in order to successfully collect proximity trace data. Click here to start the app. Thank you for your participation.", arguments: nil)
        let r = UNNotificationRequest(identifier: "\(UNNotificationCategory.openApp)-\(index)",
                                      content: nc,
                                      trigger: trigger)
        scheduleNotification(r)
    }
    
    private static func scheduleNotification(_ request: UNNotificationRequest) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings(completionHandler: { (settings) in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            center.add(request, withCompletionHandler: nil)
            os_log("Added notification request (.identifier=%@ .content.categoryIdentifier=%@ .content.threadIdentifier=%@) to user notification center.", log: .app, request.identifier, request.content.categoryIdentifier, request.content.threadIdentifier)
        })
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // We will update .badge in the app
//        showAlert(withText: notification.request.content.body)
        completionHandler([.alert, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//        showAlert(withText: notification.request.content.body)
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
    }
    
    // MARK: - Remote
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        print("application: didRegisterForRemoteNotificationsWithDeviceToken: \(token)")
        AppDelegate.deviceToken = token
        
        if AuthenticationUtil.isAuthenticated() {
            postRequest = DataSource.postUser(cognitoId: AuthenticationUtil.cognitoId, email: AuthenticationUtil.cognitoEmail, deviceToken: AppDelegate.deviceToken)
                postRequest?.subscribe(onNext: { value in
                    AuthenticationUtil.user = value
                    AppDelegate.tokenRequested = false
                    return
                }, onError: { error in
                    showError(errorMessage: error.localizedDescription)
                    AppDelegate.tokenRequested = false
                })
        }
        else {
            AppDelegate.tokenRequested = false
        }
    }
}
