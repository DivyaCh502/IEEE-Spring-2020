//
//  CustomButton.swift
//  UIComponents
//
//  Created by Volkov Alexander on 5/2/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit

@IBDesignable public class CustomButton: UIButton {
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = self.bounds.height / 2
        self.layer.masksToBounds = true
    }
    
}
