//
//  UserPostResponse.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation

struct UserPostResponse: Codable {
    var isAppTester: Bool?
}

extension UserPostResponse: GenericPasswordConvertible {
    
    init<D>(rawRepresentation data: D) throws where D : ContiguousBytes {
        let data = data as! Data
        let info = try! JSONDecoder().decode(UserPostResponse.self, from: data)
        self.isAppTester = info.isAppTester
    }
    
    var rawRepresentation: Data {
        return try! JSONEncoder().encode(self)
    }
}

