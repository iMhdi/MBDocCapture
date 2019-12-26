//
//  ImageScannerController.swift
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

/// A set of methods that your delegate object must implement to interact with the image scanner interface.
public protocol ImageScannerControllerDelegate: NSObjectProtocol {
    
    /// Tells the delegate that the user scanned a document.
    ///
    /// - Parameters:
    ///   - scanner: The scanner controller object managing the scanning interface.
    ///   - results: The results of the user scanning with the camera.
    /// - Discussion: Your delegate's implementation of this method should dismiss the image scanner controller.
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults)
    
    /// Tells the delegate that the user scanned a document.
    ///
    /// - Parameters:
    ///   - scanner: The scanner controller object managing the scanning interface.
    ///   - page1Results: The results of the user scanning page 1.
    ///   - page2Results: The results of the user scanning page 2.
    /// - Discussion: Your delegate's implementation of this method should dismiss the image scanner controller.
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithPage1Results page1Results: ImageScannerResults, andPage2Results page2Results: ImageScannerResults)
    
    /// Tells the delegate that the user cancelled the scan operation.
    ///
    /// - Parameters:
    ///   - scanner: The scanner controller object managing the scanning interface.
    /// - Discussion: Your delegate's implementation of this method should dismiss the image scanner controller.
    func imageScannerControllerDidCancel(_ scanner: ImageScannerController)
    
    /// Tells the delegate that an error occured during the user's scanning experience.
    ///
    /// - Parameters:
    ///   - scanner: The scanner controller object managing the scanning interface.
    ///   - error: The error that occured.
    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error)
}

/// A view controller that manages the full flow for scanning documents.
/// The `ImageScannerController` class is meant to be presented. It consists of a series of 3 different screens which guide the user:
/// 1. Uses the camera to capture an image with a rectangle that has been detected.
/// 2. Edit the detected rectangle.
/// 3. Review the cropped down version of the rectangle.
public final class ImageScannerController: UINavigationController {
    
    /// The object that acts as the delegate of the `ImageScannerController`.
    weak public var imageScannerDelegate: ImageScannerControllerDelegate?
    
    public var shouldScanTwoFaces: Bool = false {
        didSet {
            CaptureSession.current.isScanningTwoFacedDocument = shouldScanTwoFaces
        }
    }
    
    // MARK: - Life Cycle
    
    /// A black UIView, used to quickly display a black screen when the shutter button is presseed.
    internal let blackFlashView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    public required init(image: UIImage? = nil, delegate: ImageScannerControllerDelegate? = nil) {
        super.init(rootViewController: ScannerViewController())
        
        self.imageScannerDelegate = delegate
        
        navigationBar.tintColor = .white
        self.view.addSubview(blackFlashView)
        setupConstraints()
        
        // If an image was passed in by the host app (e.g. picked from the photo library), use it instead of the document scanner.
        if let image = image {
            
            var detectedRect: Rectangle?
            
            // Whether or not we detect a rect, present the edit view controller after attempting to detect a rect.
            defer {
                let editViewController = EditScanViewController(image: image, rect: detectedRect, rotateImage: false)
                setViewControllers([editViewController], animated: false)
            }
            
            guard let ciImage = CIImage(image: image) else { return }
            
            detectedRect = CIRectangleDetector.rectangle(forImage: ciImage)
            detectedRect?.reorganize()
        }
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupConstraints() {
        let blackFlashViewConstraints = [
            blackFlashView.topAnchor.constraint(equalTo: view.topAnchor),
            blackFlashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: blackFlashView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: blackFlashView.trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(blackFlashViewConstraints)
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override public var shouldAutorotate: Bool {
        return true
    }
    
    override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    internal func flashToBlack() {
        view.bringSubviewToFront(blackFlashView)
        blackFlashView.isHidden = false
        let flashDuration = DispatchTime.now() + 0.05
        DispatchQueue.main.asyncAfter(deadline: flashDuration) {
            self.blackFlashView.isHidden = true
        }
    }
}

/// Data structure containing information about a scan.
public struct ImageScannerResults {
    
    /// The original image taken by the user, prior to the cropping applied.
    public var originalImage: UIImage
    
    /// The deskewed and cropped orignal image using the detected rectangle, without any filters.
    public var scannedImage: UIImage
    
    /// The enhanced image, passed through an Adaptive Thresholding function. This image will always be grayscale and may not always be available.
    public var enhancedImage: UIImage?
    
    /// Whether the user wants to use the enhanced image or not. The `enhancedImage`, for use with OCR or similar uses, may still be available even if it has not been selected by the user.
    public var doesUserPreferEnhancedImage: Bool
    
    /// The detected rectangle which was used to generate the `scannedImage`.
    public var detectedRectangle: Rectangle
    
}

extension UIViewController {

    func bundle() -> Bundle {
        let frameworkBundle = Bundle(for: type(of: self))
        let bundleURL = frameworkBundle.resourceURL?.appendingPathComponent("MBDocCapture.bundle")
        
        if let bundle = Bundle(url: bundleURL!) {
            return bundle
        } else {
            return Bundle(for: type(of: self))
        }
    }
}
