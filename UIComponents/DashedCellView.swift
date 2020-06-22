//
//  DashedCellView.swift
//  UIComponents
//
//  Created by Volkov Alexander on 5/1/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit

/// Dashed line
@IBDesignable public class DashedCellView: UIView {
    
    @IBInspectable public var iconPadding: CGFloat = 25 { didSet { setNeedsDisplay() } }
    @IBInspectable public var iconSize: CGFloat = 75 { didSet { setNeedsDisplay() } }
    @IBInspectable public var isLeft: Bool = true { didSet { setNeedsDisplay() } }
    @IBInspectable public var isFirst: Bool = false { didSet { setNeedsDisplay() } }
    
    override public func draw(_ rect: CGRect) {
        let lineWidth: CGFloat = 2
        let r1 = CGFloat((self.bounds.height - iconSize) / 2) - lineWidth / 2
        let r2 = r1
        // Center of the first top (left or right) arc
        var c1 = CGPoint(x: iconPadding + iconSize / 2 + r1, y: (self.bounds.height - iconSize) / 2)
        var c3 = c1
        if !isLeft {
            c1 = CGPoint(x: self.bounds.width - c1.x, y: c1.y)
        }
        else {
            c3 = CGPoint(x: self.bounds.width - c1.x, y: c1.y)
        }
        // Center of the bottom arc
        let c2 = CGPoint(x: c1.x, y: c1.y + iconSize)
        var path1: UIBezierPath!
        if isFirst {
            path1 = UIBezierPath()
            path1.move(to: CGPoint(x: c1.x - r2, y: 0))
            path1.addLine(to: CGPoint(x: c1.x - r2, y: c1.y))
        }
        else {
            path1 = UIBezierPath(arcCenter: c1, radius: r2, startAngle: -.pi/2, endAngle: isLeft ? .pi : 0, clockwise: !isLeft)
        }
        
        let path2 = UIBezierPath(arcCenter: c2, radius: r1, startAngle: !isLeft ? 0 : .pi, endAngle: .pi/2, clockwise: !isLeft)
        
        let path3 = UIBezierPath()
        path3.move(to: CGPoint(x: c1.x, y: self.bounds.height - lineWidth / 2))
        path3.addLine(to: CGPoint(x: self.bounds.width / 2, y: self.bounds.height - lineWidth / 2))
        let path4 = UIBezierPath() // top horizontal line
        path4.move(to: CGPoint(x: c1.x, y: lineWidth / 2))
        path4.addLine(to: CGPoint(x: self.bounds.width / 2, y: lineWidth / 2))
//        let path3 = UIBezierPath()
//        path3.move(to: CGPoint(x: c1.x, y: self.bounds.height - lineWidth / 2))
//        path3.addLine(to: CGPoint(x: c3.x, y: self.bounds.height - lineWidth / 2))
        
        let context = UIGraphicsGetCurrentContext()!
        if #available(iOS 13.0, *) {
            context.setStrokeColor(UIColor.label.cgColor)
        } else {
            context.setStrokeColor(UIColor.black.cgColor)
        }
        context.setLineWidth(lineWidth)
        context.setLineDash(phase: 0, lengths: [4,4])
        context.setLineCap(.butt)
        context.addPath(path1.cgPath)
        context.addPath(path2.cgPath)
        context.addPath(path3.cgPath)
        context.drawPath(using: .stroke)
        
        context.setLineDash(phase: 1, lengths: [0,4,4,0])
        if !isFirst {
            context.addPath(path4.cgPath)
        }
        context.drawPath(using: .stroke)
        
    }
}
