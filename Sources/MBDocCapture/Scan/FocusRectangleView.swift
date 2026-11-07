//
//  FocusRectangleView.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit

/// The square shown at the last tap-to-focus point, shrinking in like the Camera app.
final class FocusRectangleView: UIView {

    convenience init(touchPoint: CGPoint, color: UIColor) {
        let originalSize: CGFloat = 160
        let finalSize: CGFloat = 76
        self.init(frame: CGRect(x: touchPoint.x - originalSize / 2, y: touchPoint.y - originalSize / 2, width: originalSize, height: originalSize))
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.borderWidth = 1.5
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderColor = color.cgColor

        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.frame = self.frame.insetBy(dx: (originalSize - finalSize) / 2, dy: (originalSize - finalSize) / 2)
        }
    }
}
