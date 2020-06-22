//
//  AuthenticationUtil.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation
import SwiftEx

/// Authentication util
class AuthenticationUtil {
    
    /// authentication response
    static var response: AuthResponse? {
        get {
            if let res = _response {
                return res
            }
            _response = try? GenericPasswordStore().readKey(account: "authResponse")
            return _response
        }
        set {
            self._response = newValue
            if let value = newValue {
                #if DEBUG
                let list = getClaims(fromToken: value.id_token ?? "")
                print("STORING: \(list)")
                #endif
                try? GenericPasswordStore().storeKey(value, account: "authResponse")
                UserDefaults.isAuthenticated = true
            }
            else {
                try? GenericPasswordStore().deleteKey(account: "authResponse")
                UserDefaults.isAuthenticated = false
            }
        }
    }
    static var _response: AuthResponse?
    
    /// the user's response
    static var user: UserPostResponse? {
        get {
            if let u = _user {
                return u
            }
            self._user = try? GenericPasswordStore().readKey(account: "user")
            return self._user
        }
        set {
            self._user = newValue
            if let value = newValue { try? GenericPasswordStore().storeKey(value, account: "user") }
            else { try? GenericPasswordStore().deleteKey(account: "user") }
        }
    }
    static var _user: UserPostResponse?
    
    static var cognitoId: String? {
        guard let res = response else { return nil }
        let list = getClaims(fromToken: res.id_token ?? "")
        return list["sub"] as? String
    }
    
    static var cognitoEmail: String? {
        guard let res = response else { return nil }
        let list = getClaims(fromToken: res.id_token ?? "")
        let fakeId = cognitoId ?? "any"
        return (list["email"] as? String) ?? "\(fakeId)@sample.com"
    }
    
    static var isTester: Bool {
        #if DEBUG
        return true
        #endif
        guard let res = response else { return true }
        let list = getClaims(fromToken: res.id_token ?? "")
        if let role = list["custom:role"] as? String {
            return role == "test"
        }
        return user?.isAppTester ?? true
    }
    
    static func isAuthenticated() -> Bool {
        return UserDefaults.isAuthenticated
    }
    
    static func cleanUp() {
        response = nil
        user = nil
        DataSource.headers = [:]
        UserDefaults.isAuthenticated = false
    }
    
    static func processCredentials(_ response: AuthResponse) {
        self.response = response
        DataSource.headers = [DataSource.AUTH_HEADER: "Bearer \(response.access_token ?? "")"]
    }
    
    static func getClaims(fromToken token: String) -> [AnyHashable: Any] {
        let pieces = token.components(separatedBy: ".")
        if pieces.count > 2 {
            var claims: String = String(pieces[1])
            let paddedLength = claims.length + (4 - (claims.length % 4)) % 4
            claims = (claims as NSString).padding(toLength: paddedLength, withPad: "=", startingAt: 0)
            if let claimsData: Data = Data(base64Encoded: claims, options: Data.Base64DecodingOptions.ignoreUnknownCharacters) {
                let result: [AnyHashable: Any] = (try? JSONSerialization.jsonObject(with: claimsData)) as! [AnyHashable: Any]
                return result
            }
            else {
                print("Token is not valid base64")
            }
        }
        return [:]
    }
}
