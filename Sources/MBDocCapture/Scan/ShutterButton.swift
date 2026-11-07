//
//  ShutterButton.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit

/// The shutter: an outer ring and an inner disc that shrinks while pressed.
final class ShutterButton: UIControl {

    private let outerRingLayer = CAShapeLayer()
    private let innerCircleLayer = CAShapeLayer()
    private let outerRingRatio: CGFloat = 0.86
    private let innerCircleRatio: CGFloat = 0.78
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    var isHapticFeedbackEnabled = true

    var color: UIColor = .white {
        didSet { setNeedsLayout() }
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            UIView.animate(withDuration: isHighlighted ? 0.25 : 0.15, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.innerCircleLayer.setAffineTransform(self.isHighlighted ? CGAffineTransform(scaleX: 0.88, y: 0.88) : .identity)
            }
            if isHighlighted, isHapticFeedbackEnabled { impactFeedbackGenerator.impactOccurred() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(outerRingLayer)
        layer.addSublayer(innerCircleLayer)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .button
        impactFeedbackGenerator.prepare()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let ring = UIBezierPath(ovalIn: bounds)
        ring.append(UIBezierPath(ovalIn: bounds.scaleAndCenter(withRatio: outerRingRatio)).reversing())
        outerRingLayer.frame = bounds
        outerRingLayer.path = ring.cgPath
        outerRingLayer.fillColor = color.cgColor

        innerCircleLayer.frame = bounds
        innerCircleLayer.path = UIBezierPath(ovalIn: bounds.scaleAndCenter(withRatio: innerCircleRatio)).cgPath
        innerCircleLayer.fillColor = color.cgColor
    }
}
