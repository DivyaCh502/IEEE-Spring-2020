//
//  Configuration.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation

/// App configuration
class Configuration {
    
    /// data
    var dict = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "configuration", ofType: "plist")!)
    
    /// singleton
    static let shared = Configuration()
    
    /// the client ID
    static var clientId: String {
        return shared.dict!["clientId"] as! String
    }
    
    /// the login URL
    static var cognitoLoginUrl: String {
        return (shared.dict!["cognitoLoginUrl"] as! String).replace("%clientId%", withString: Configuration.clientId)
    }
    
    /// The token endpoint. Add code at the end of URL.
    static var cognitoGetTokenUrl: String {
        return (shared.dict!["cognitoGetTokenUrl"] as! String).replace("%clientId%", withString: Configuration.clientId)
    }
    
    /// The token refresh endpoint.
    static var cognitoGetRefreshTokenUrl: String {
        return (shared.dict!["cognitoGetRefreshTokenUrl"] as! String).replace("%clientId%", withString: Configuration.clientId)
    }
    
    static var baseUrl: String {
        return shared.dict!["baseUrl"] as! String
    }
    
    static var appCenterSecret: String {
        return shared.dict!["appCenterSecret"] as! String
    }
    
    static var backgroundFetchInterval: TimeInterval {
        return (shared.dict!["backgroundFetchInterval"] as! NSNumber).doubleValue
    }
    
    static var reminderNotificationHour: Int {
        return (shared.dict!["reminderNotificationHour"] as! NSNumber).intValue
    }
    
    static var reminderNotificationMinute: Int {
        return (shared.dict!["reminderNotificationMinute"] as! NSNumber).intValue
    }
    
    // the login callback
    static var appLoginCallback: String = "app://callback"
    
}
