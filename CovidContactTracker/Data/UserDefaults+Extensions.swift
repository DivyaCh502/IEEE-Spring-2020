//
//  UserDefaultsExtensions.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/3/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation
import TCNClient

extension UserDefaults {
    
    public struct Key {
        // dodo remove?
        public static let isCurrentUserSick = "isCurrentUserSick"
//        public static let wasCurrentUserNotifiedOfExposure = "wasCurrentUserNotifiedOfExposure"
//        public static let isTemporaryContactNumberLoggingEnabled = "isTemporaryContactNumberLoggingEnabled"
//        public static let lastFetchDate = "lastFetchDate"
        public static let shouldStartBluetooth = "shouldStartBluetooth"
        public static let isAuthenticated = "isAuthenticated"

        // TemporaryContactKey
        public static let currentTemporaryContactKeyIndex = "currentTemporaryContactKeyIndex"
        public static let currentTemporaryContactKeyReportVerificationPublicKeyBytes = "currentTemporaryContactKeyReportVerificationPublicKeyBytes"
        public static let currentTemporaryContactKeyBytes = "currentTemporaryContactKeyBytes"


//        public static let registration: [String : Any] = [
//            isCurrentUserSick: false,
//            wasCurrentUserNotifiedOfExposure: false,
//            isTemporaryContactNumberLoggingEnabled: true,
//        ]
    }

    @objc dynamic public var isCurrentUserSick: Bool {
        return bool(forKey: Key.isCurrentUserSick)
    }

    // flag: true - if service should be started/running, false - else
    @objc dynamic public var shouldStartBluetooth: Bool {
        return bool(forKey: Key.shouldStartBluetooth)
    }
    
    static public var shouldStartBluetooth: Bool {
        get {
            UserDefaults.standard.value(forKey: Key.shouldStartBluetooth) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Key.shouldStartBluetooth)
            UserDefaults.standard.synchronize()
        }
    }
    
    static public var isAuthenticated: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.isAuthenticated)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Key.isAuthenticated)
            UserDefaults.standard.synchronize()
        }
    }
//
//    @objc dynamic public var isTemporaryContactNumberLoggingEnabled: Bool {
//        return bool(forKey: Key.isTemporaryContactNumberLoggingEnabled)
//    }
//
//    @objc dynamic public var lastFetchDate: Date? {
//        return object(forKey: Key.lastFetchDate) as? Date
//    }
    
    public var currentTemporaryContactKey: TemporaryContactKey? {
        get {
            if let index = UserDefaults.standard.object(forKey: UserDefaults.Key.currentTemporaryContactKeyIndex) as? UInt16,
                let reportVerificationPublicKeyBytes = UserDefaults.standard.object(forKey: UserDefaults.Key.currentTemporaryContactKeyReportVerificationPublicKeyBytes) as? Data,
                let temporaryContactKeyBytes = UserDefaults.standard.object(forKey: UserDefaults.Key.currentTemporaryContactKeyBytes) as? Data {
                
                return TemporaryContactKey(
                    index: index,
                    reportVerificationPublicKeyBytes: reportVerificationPublicKeyBytes,
                    bytes: temporaryContactKeyBytes
                )
            }
            
            return nil
        }
        set {
            setValue(newValue?.index, forKey: UserDefaults.Key.currentTemporaryContactKeyIndex)
            setValue(newValue?.reportVerificationPublicKeyBytes, forKey: UserDefaults.Key.currentTemporaryContactKeyReportVerificationPublicKeyBytes)
            setValue(newValue?.bytes, forKey: UserDefaults.Key.currentTemporaryContactKeyBytes)
        }
    }
    
}
