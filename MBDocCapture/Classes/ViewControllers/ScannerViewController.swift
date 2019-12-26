//
//  ScannerViewController.swift
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

/// The `ScannerViewController` offers an interface to give feedback to the user regarding rectangles that are detected. It also gives the user the opportunity to capture an image with a detected rectangle.
final class ScannerViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    
    private var prepOverlayView: UIView!
    
    private var captureSessionManager: CaptureSessionManager?
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView!
    
    /// The view that draws the detected rectangles.
    private let rectView = RectangleView()
            
    lazy private var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override public var shouldAutorotate: Bool {
        return true
    }
    
    override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    lazy private var cancelButton: UIBarButtonItem = {
        let title = NSLocalizedString("mbdoccapture.cancel_button", tableName: nil, bundle: bundle(), value: "Cancel", comment: "")
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(cancelImageScannerController))
        button.tintColor = .white
        return button
    }()
    
    lazy private var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = nil
        
        setupViews()
        setupNavigationBar()
        setupConstraints()
        
        captureSessionManager = CaptureSessionManager(videoPreviewLayer: videoPreviewLayer)
        captureSessionManager?.delegate = self
                
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
        //        NotificationCenter.default.addObserver(self, selector: #selector(updateCameraOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        
        CaptureSession.current.isEditing = false
        rectView.removeRectangle()
        captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true
                
        navigationController?.setToolbarHidden(true, animated: false)
        
        if CaptureSession.current.isScanningTwoFacedDocument {
            if let _ = CaptureSession.current.firstScanResult {
                displayPrepOverlay()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCameraOrientation()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        videoPreviewLayer.frame = view.layer.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        updateCameraOrientation()
    }
    
    @objc private func updateCameraOrientation() {
        if UIDevice.current.orientation == .landscapeRight {
            videoPreviewLayer.connection!.videoOrientation       = .landscapeLeft
        } else if UIDevice.current.orientation == .landscapeLeft {
            videoPreviewLayer.connection!.videoOrientation       = .landscapeRight
        } else if UIDevice.current.orientation == .portrait {
            videoPreviewLayer.connection!.videoOrientation       = .portrait
        } else if UIDevice.current.orientation == .portraitUpsideDown {
            videoPreviewLayer.connection!.videoOrientation       = .portraitUpsideDown
        }
        
        videoPreviewLayer.frame = view.layer.bounds
    }
    
    // MARK: - Setups
    
    private func setupViews() {
        view.layer.addSublayer(videoPreviewLayer)
        rectView.translatesAutoresizingMaskIntoConstraints = false
        rectView.editable = false
        view.addSubview(rectView)
        view.addSubview(shutterButton)
        view.addSubview(activityIndicator)
    }
    
    private func setupNavigationBar() {
        navigationItem.setLeftBarButton(cancelButton, animated: false)
        
        if #available(iOS 13.0, *) {
            isModalInPresentation = false
            navigationController?.presentationController?.delegate = self
        }
    }
    
    private func setupConstraints() {
        var rectViewConstraints = [NSLayoutConstraint]()
        var shutterButtonConstraints = [NSLayoutConstraint]()
        var activityIndicatorConstraints = [NSLayoutConstraint]()
        
        rectViewConstraints = [
            rectView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: rectView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: rectView.trailingAnchor),
            rectView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ]
        
        shutterButtonConstraints = [
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 65.0),
            shutterButton.heightAnchor.constraint(equalToConstant: 65.0)
        ]
        
        activityIndicatorConstraints = [
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]
        
        if #available(iOS 11.0, *) {
            let shutterButtonBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        } else {
            let shutterButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        }
        
        NSLayoutConstraint.activate(rectViewConstraints + shutterButtonConstraints + activityIndicatorConstraints)
    }
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return false
    }
    
    // MARK: - Tap to Focus
    
    /// Called when the AVCaptureDevice detects that the subject area has changed significantly. When it's called, we reset the focus so the camera is no longer out of focus.
    @objc private func subjectAreaDidChange() {
        /// Reset the focus and exposure back to automatic
        do {
            try CaptureSession.current.resetFocusToAuto()
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
        
        /// Remove the focus rectangle if one exists
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: true)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard  let touch = touches.first else { return }
        let touchPoint = touch.location(in: view)
        let convertedTouchPoint: CGPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: false)
        
        focusRectangle = FocusRectangleView(touchPoint: touchPoint)
        view.addSubview(focusRectangle)
        
        do {
            try CaptureSession.current.setFocusPointToTapPoint(convertedTouchPoint)
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
    }
    
    // MARK: - Actions
    
    @objc private func captureImage(_ sender: UIButton) {
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }
    
    @objc func autoCaptureSwitchValueDidChange(sender:UISwitch!) {
        if sender.isOn {
            CaptureSession.current.isAutoScanEnabled = true
        } else {
            CaptureSession.current.isAutoScanEnabled = false
        }
    }
    
    @objc private func cancelImageScannerController() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerControllerDidCancel(imageScannerController)
    }
}

extension ScannerViewController: RectangleDetectionDelegateProtocol {
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        
        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true
        
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
    }
    
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        shutterButton.isUserInteractionEnabled = false
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withRect rect: Rectangle?) {
        activityIndicator.stopAnimating()
        
        let editVC = EditScanViewController(image: picture, rect: rect)
        navigationController?.pushViewController(editVC, animated: false)
        
        shutterButton.isUserInteractionEnabled = true
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectRect rect: Rectangle?, _ imageSize: CGSize) {
        guard let rect = rect else {
            // If no rect has been detected, we remove the currently displayed on on the rectView.
            rectView.removeRectangle()
            return
        }
        
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: rectView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
        
        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)
        
        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: rectView.bounds)
        
        let transforms = [scaleTransform, rotationTransform, translationTransform]
        
        let transformedRect = rect.applyTransforms(transforms)
        
        rectView.drawRectangle(rect: transformedRect, animated: true)
    }
    
    func displayPrepOverlay() {
        CaptureSession.current.isEditing = true
        
        prepOverlayView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 120))
        prepOverlayView.backgroundColor = UIColor(hexString: "FFFFFF99")
        
        let image = UIImageView(frame: CGRect(x: (view.frame.width - 40) / 2, y: 16, width: 40, height: 40))
        let icon = UIImage(named: "ic_touch", in: bundle(), compatibleWith: nil)
        image.image = icon
        prepOverlayView.addSubview(image)
        
        let defaultFont = UIFont(name: "HelveticaNeue-Bold", size: 15)
        let label = UILabel(frame: CGRect(x: 16, y: image.frame.maxY + 16, width: prepOverlayView.frame.width - 32, height: 40))
        label.font = defaultFont
        label.numberOfLines = 0
        label.textColor = .black
        label.textAlignment = .center
        label.text = NSLocalizedString("mbdoccapture.document_capture_flip", tableName: nil, bundle: bundle(), value: "Flip your document and Touch the screen when you're ready to start the capture.", comment: "")
        prepOverlayView.addSubview(label)
        
        let button = UIButton(frame: view.bounds)
        button.backgroundColor = .clear
        button.setTitle("", for: .normal)
        button.addTarget(self, action: #selector(didSelectRemoveOverlay(_:)), for: .touchUpInside)
        
        prepOverlayView.center = self.view.center
        view.addSubview(prepOverlayView)
        view.addSubview(button)
    }
    
    @objc func didSelectRemoveOverlay(_ button: UIButton) {
        button.removeFromSuperview()
        prepOverlayView.removeFromSuperview()
        CaptureSession.current.isEditing = false
    }
}
