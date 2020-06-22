//
//  CircleAnimatedView.swift
//  UIComponents
//
//  Created by Volkov Alexander on 5/12/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import UIKit

public class CircleAnimatedView: UIView {
    
    var animatableLayers = [CAShapeLayer]()
    
    private let duration: TimeInterval = 10
    
    private var isAnimating = false
    
    private func addCircles() {
        addCircle()
        addCircle(delay: 2)
        addCircle(delay: 4)
        addCircle(delay: 6)
        addCircle(delay: 8)
        isAnimating = true
    }
    
    public func updateAnimations() {
        var d: TimeInterval = 0
        for l in animatableLayers {
            if l.animation(forKey: "transform.scale") == nil {
                l.removeAllAnimations()
                self.startAnimation(layer: l, delay: d)
            }
            d += 2
        }
        isAnimating = true
    }
    
    public func tryUpdateAnimations() {
        if !isAnimating {
            updateAnimations()
        }
    }
    
    public func removeAnimations() {
        for l in animatableLayers {
            l.removeAllAnimations()
            l.opacity = 0
        }
        isAnimating = false
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        if animatableLayers.isEmpty {
            addCircles()
        }
        for layer in animatableLayers {
            layer.path = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.layer.cornerRadius).cgPath
        }
    }
    
    private func addCircle(delay: TimeInterval = 0) {
        let circle = CAShapeLayer()
        circle.fillColor = UIColor(white: 0, alpha: 0.1).cgColor
        circle.path = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.layer.cornerRadius).cgPath
        circle.frame = self.bounds
        circle.cornerRadius = self.bounds.height/2
        circle.masksToBounds = true
        self.layer.addSublayer(circle)
        self.startAnimation(layer: circle, delay: delay)
        animatableLayers.append(circle)
    }
    
    func startAnimation(layer: CAShapeLayer, delay: TimeInterval = 0) {
        layer.opacity = 0
        CATransaction.begin()
        do {
            let a = CABasicAnimation(keyPath: "transform.scale")
            a.fromValue = 0.05
            a.toValue = 1.7
            a.isAdditive = false
            a.duration = CFTimeInterval(duration)
            a.beginTime = CACurrentMediaTime() + delay
            a.fillMode = CAMediaTimingFillMode.forwards
            a.isRemovedOnCompletion = false
            a.repeatCount = .infinity
            a.autoreverses = false
            layer.add(a, forKey: "growingAnimation")
        }
        do {
            let a = CABasicAnimation(keyPath: "opacity")
            a.fromValue = 1
            a.toValue = 0
            a.isAdditive = false
            a.duration = CFTimeInterval(duration)
            a.beginTime = CACurrentMediaTime() + delay
            a.fillMode = CAMediaTimingFillMode.forwards
            a.isRemovedOnCompletion = false
            a.repeatCount = .infinity
            a.autoreverses = false
            layer.add(a, forKey: "alphaAnimation")
        }
        CATransaction.commit()
    }
}
