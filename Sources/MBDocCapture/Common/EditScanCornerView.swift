//
//  EditScanCornerView.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit

/// A round corner handle of the editable quadrilateral. While dragged, it grows and shows a magnified crop of the image.
final class EditScanCornerView: UIView {

    let position: CornerPosition

    /// The image to display when the corner view is highlighted.
    private var image: UIImage?

    private(set) var isHighlighted = false

    private let color: UIColor

    private lazy var circleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineWidth = 2.0
        layer.strokeColor = color.cgColor
        return layer
    }()

    init(frame: CGRect, position: CornerPosition, color: UIColor) {
        self.position = position
        self.color = color
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        layer.addSublayer(circleLayer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2.0
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        circleLayer.frame = rect
        circleLayer.path = UIBezierPath(ovalIn: rect.insetBy(dx: circleLayer.lineWidth, dy: circleLayer.lineWidth)).cgPath
        // The outline layer sits above the drawn content, so the magnified image shows through a clear fill.
        circleLayer.fillColor = image == nil ? color.withAlphaComponent(0.3).cgColor : UIColor.clear.cgColor
        image?.draw(in: rect)
    }

    func highlightWithImage(_ image: UIImage) {
        isHighlighted = true
        self.image = image
        setNeedsDisplay()
    }

    func reset() {
        isHighlighted = false
        image = nil
        setNeedsDisplay()
    }
}
