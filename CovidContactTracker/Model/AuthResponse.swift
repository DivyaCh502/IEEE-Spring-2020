//
//  AuthResponse.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation

struct AuthResponse: Codable {

    var id_token: String?
    var access_token: String?
    var expires_in: Int?
    var token_type: String?
    var refresh_token: String?
}

extension AuthResponse: GenericPasswordConvertible {
    
    init<D>(rawRepresentation data: D) throws where D : ContiguousBytes {
        let data = data as! Data
        let info = try! JSONDecoder().decode(AuthResponse.self, from: data)
        self.id_token = info.id_token
        self.access_token = info.access_token
        self.expires_in = info.expires_in
        self.expires_in = info.expires_in
        self.refresh_token = info.refresh_token
    }
    
    var rawRepresentation: Data {
        return try! JSONEncoder().encode(self)
    }
}
