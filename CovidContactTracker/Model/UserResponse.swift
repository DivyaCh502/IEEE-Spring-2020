//
//  UserResponse.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation

struct UserResponse: Codable {
    
    var tcnReportRequested: Bool?
    
    func toString() -> String {
        return "{tcnReportRequested: \(tcnReportRequested?.description ?? "nil")}"
    }
}
