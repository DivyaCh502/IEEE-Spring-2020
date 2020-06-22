//
//  OSLog+Additions.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/3/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation
import os.log

extension OSLog {
    
    public static let app = OSLog(subsystem: "com.topcoder", category: "App")
}
