//
//  EditScanViewController.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019 El Mahdi Boukhris <m.boukhris@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

import UIKit
import AVFoundation

/// The `EditScanViewController` offers an interface for the user to edit the detected rectangle.
final class EditScanViewController: UIViewController {
    
    lazy private var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.isOpaque = true
        imageView.image = image
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    lazy private var rectView: RectangleView = {
        let rectView = RectangleView()
        rectView.editable = true
        rectView.translatesAutoresizingMaskIntoConstraints = false
        return rectView
    }()
    
    lazy private var nextButton: UIBarButtonItem = {
        let title = NSLocalizedString("mbdoccapture.next_button", tableName: nil, bundle: bundle(), value: "Next", comment: "")
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(pushReviewController))
        button.tintColor = .white
        return button
    }()

    /// The image the rectangle was detected on.
    private let image: UIImage
    
    /// The detected rectangle that can be edited by the user. Uses the image's coordinates.
    private var rect: Rectangle
    
    private var zoomGestureController: ZoomGestureController!
    
    private var rectViewWidthConstraint = NSLayoutConstraint()
    private var rectViewHeightConstraint = NSLayoutConstraint()
    
    // MARK: - Life Cycle
    
    init(image: UIImage, rect: Rectangle?, rotateImage: Bool = true) {
        self.image = rotateImage ? image.applyingPortraitOrientation() : image
        self.rect = rect ?? EditScanViewController.defaultRectangle(forImage: image)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupConstraints()
        title = NSLocalizedString("mbdoccapture.scan_edit_title", tableName: nil, bundle: bundle(), value: "Trimming", comment: "")
        navigationItem.rightBarButtonItem = nextButton
        
        zoomGestureController = ZoomGestureController(image: image, rectView: rectView)
        
        let touchDown = UILongPressGestureRecognizer(target: zoomGestureController, action: #selector(zoomGestureController.handle(pan:)))
        touchDown.minimumPressDuration = 0
        view.addGestureRecognizer(touchDown)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustRectViewConstraints()
        displayRect()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Work around for an iOS 11.2 bug where UIBarButtonItems don't get back to their normal state after being pressed.
        navigationController?.navigationBar.tintAdjustmentMode = .normal
        navigationController?.navigationBar.tintAdjustmentMode = .automatic
    }
    
    // MARK: - Setups
    
    private func setupViews() {
        view.addSubview(imageView)
        view.addSubview(rectView)
    }
    
    private func setupConstraints() {
        let imageViewConstraints = [
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: imageView.leadingAnchor)
        ]

        rectViewWidthConstraint = rectView.widthAnchor.constraint(equalToConstant: 0.0)
        rectViewHeightConstraint = rectView.heightAnchor.constraint(equalToConstant: 0.0)
        
        let rectViewConstraints = [
            rectView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rectView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            rectViewWidthConstraint,
            rectViewHeightConstraint
        ]
        
        NSLayoutConstraint.activate(rectViewConstraints + imageViewConstraints)
    }
    
    // MARK: - Actions
    
    @objc func pushReviewController() {
        guard let rect = rectView.rect,
            let ciImage = CIImage(image: image) else {
                if let imageScannerController = navigationController as? ImageScannerController {
                    let error = ImageScannerControllerError.ciImageCreation
                    imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
                }
                return
        }
        
        let scaledRect = rect.scale(rectView.bounds.size, image.size)
        self.rect = scaledRect
        
        var cartesianScaledRect = scaledRect.toCartesian(withHeight: image.size.height)
        cartesianScaledRect.reorganize()
        
        let filteredImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesianScaledRect.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesianScaledRect.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesianScaledRect.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesianScaledRect.topRight)
            ])
        
        let enhancedImage = filteredImage.applyingAdaptiveThreshold()?.withFixedOrientation()
        
        var uiImage: UIImage!
        
        // Let's try to generate the CGImage from the CIImage before creating a UIImage.
        if let cgImage = CIContext(options: nil).createCGImage(filteredImage, from: filteredImage.extent) {
            uiImage = UIImage(cgImage: cgImage)
        } else {
            uiImage = UIImage(ciImage: filteredImage, scale: 1.0, orientation: .up)
        }
        
        let finalImage = uiImage.withFixedOrientation()
        
        let results = ImageScannerResults(originalImage: image, scannedImage: finalImage, enhancedImage: enhancedImage, doesUserPreferEnhancedImage: false, detectedRectangle: scaledRect)
        let reviewViewController = ReviewViewController(results: results)
        
        navigationController?.pushViewController(reviewViewController, animated: true)
    }

    private func displayRect() {
        let imageSize = image.size
        let imageFrame = CGRect(origin: rectView.frame.origin, size: CGSize(width: rectViewWidthConstraint.constant, height: rectViewHeightConstraint.constant))
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: imageSize, aspectFillInSize: imageFrame.size)
        let transforms = [scaleTransform]
        let transformedRect = rect.applyTransforms(transforms)
        
        rectView.drawRectangle(rect: transformedRect, animated: false)
    }
    
    /// The rectView should be lined up on top of the actual image displayed by the imageView.
    /// Since there is no way to know the size of that image before run time, we adjust the constraints to make sure that the rectView is on top of the displayed image.
    private func adjustRectViewConstraints() {
        let frame = AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
        rectViewWidthConstraint.constant = frame.size.width
        rectViewHeightConstraint.constant = frame.size.height
    }
    
    /// Generates a `Rectangle` object that's centered and one third of the size of the passed in image.
    private static func defaultRectangle(forImage image: UIImage) -> Rectangle {
        let topLeft = CGPoint(x: image.size.width / 3.0, y: image.size.height / 3.0)
        let topRight = CGPoint(x: 2.0 * image.size.width / 3.0, y: image.size.height / 3.0)
        let bottomRight = CGPoint(x: 2.0 * image.size.width / 3.0, y: 2.0 * image.size.height / 3.0)
        let bottomLeft = CGPoint(x: image.size.width / 3.0, y: 2.0 * image.size.height / 3.0)
        
        let rect = Rectangle(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
        
        return rect
    }
}
