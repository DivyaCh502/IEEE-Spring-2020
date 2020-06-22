//
//  DashedEndingView.swift
//  UIComponents
//
//  Created by Volkov Alexander on 5/2/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit

/// Dashed line at the end
@IBDesignable class DashedEndingView: UIView {
    
    @IBInspectable var iconPadding: CGFloat = 25 { didSet { setNeedsDisplay() } }
    @IBInspectable var iconSize: CGFloat = 75 { didSet { setNeedsDisplay() } }
    @IBInspectable var isLeft: Bool = true { didSet { setNeedsDisplay() } }
    
    override func draw(_ rect: CGRect) {
        let lineWidth: CGFloat = 2
        let r1 = self.bounds.height - lineWidth / 2
        var c1 = CGPoint(x: iconPadding + iconSize / 2 + r1, y: self.bounds.height)
        if !isLeft {
            c1 = CGPoint(x: self.bounds.width - c1.x, y: c1.y)
        }
        let path1 = UIBezierPath(arcCenter: c1, radius: r1, startAngle: -.pi/2, endAngle: isLeft ? .pi : 0, clockwise: !isLeft)
        let path3 = UIBezierPath()
        path3.move(to: CGPoint(x: c1.x, y: lineWidth / 2))
        path3.addLine(to: CGPoint(x: self.bounds.width / 2, y: lineWidth / 2))
        
        let context = UIGraphicsGetCurrentContext()!
        context.setLineWidth(lineWidth)
        if #available(iOS 13.0, *) {
            context.setStrokeColor(UIColor.label.cgColor)
        } else {
            context.setStrokeColor(UIColor.black.cgColor)
        }
        context.setLineDash(phase: 0, lengths: [4,4])
        context.setLineCap(.butt)
        context.addPath(path1.cgPath)
        context.drawPath(using: .stroke)
        
        context.setLineDash(phase: 1, lengths: [0,4,4,0])
        context.addPath(path3.cgPath)
        context.drawPath(using: .stroke)
    }
}
