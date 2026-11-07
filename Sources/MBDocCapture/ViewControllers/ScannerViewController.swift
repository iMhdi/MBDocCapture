//
//  ScannerViewController.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit
import AVFoundation

/// Live camera screen: shows the detected document and captures it, manually or automatically.
final class ScannerViewController: UIViewController {

    private let configuration: MBDocCaptureConfiguration
    private var appearance: MBDocCaptureConfiguration.Appearance { configuration.appearance }
    private var strings: MBDocCaptureConfiguration.Strings { configuration.strings }

    private var captureSessionManager: CaptureSessionManager?
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    private var didReportMissingCamera = false
    private var isTorchOn = false
    private var isDocumentDetected = false

    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView?

    /// The view that draws the detected rectangles.
    private lazy var rectView: RectangleView = {
        let view = RectangleView(appearance: appearance)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.editable = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.color = appearance.shutterButtonColor
        button.isHapticFeedbackEnabled = configuration.behavior.isHapticFeedbackEnabled
        button.accessibilityLabel = strings.shutter
        button.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
        return button
    }()

    private lazy var shutterPlatter: UIVisualEffectView = Glass.background(appearance)

    private lazy var cancelButton: UIButton = {
        let button = Glass.button(image: appearance.icons.image(appearance.icons.cancel), appearance: appearance)
        button.accessibilityLabel = strings.cancel
        button.addTarget(self, action: #selector(cancelImageScannerController), for: .touchUpInside)
        return button
    }()

    private lazy var torchButton: UIButton = {
        let button = Glass.button(image: nil, appearance: appearance)
        button.accessibilityLabel = strings.torch
        button.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
        return button
    }()

    private lazy var autoScanButton: UIButton = {
        let button = Glass.button(image: nil, appearance: appearance)
        button.addTarget(self, action: #selector(toggleAutoScan), for: .touchUpInside)
        return button
    }()

    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = appearance.hintFont
        label.adjustsFontForContentSizeCategory = true
        label.textColor = appearance.controlForegroundColor
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private lazy var hintContainer: UIVisualEffectView = Glass.background(appearance)

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = appearance.controlForegroundColor
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    init(configuration: MBDocCaptureConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = appearance.backgroundColor

        setupViews()
        updateTorchButton()
        updateAutoScanButton()

        captureSessionManager = CaptureSessionManager(videoPreviewLayer: videoPreviewLayer, detection: configuration.detection)
        captureSessionManager?.delegate = self

        // The UI is portrait only, so is the preview.
        if let connection = videoPreviewLayer.connection {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            } else {
                connection.videoOrientation = .portrait
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        navigationController?.setToolbarHidden(true, animated: false)

        CaptureSession.current.isEditing = false
        rectView.removeRectangle()
        updateHint(isDocumentDetected: false)
        captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true

        if CaptureSession.current.isScanningTwoFacedDocument, CaptureSession.current.firstScanResult != nil {
            displayFlipOverlay()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if captureSessionManager == nil, !didReportMissingCamera {
            didReportMissingCamera = true
            (navigationController as? ImageScannerController)?.fail(with: ImageScannerControllerError.inputDevice)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        UIApplication.shared.isIdleTimerDisabled = false
        if isTorchOn { toggleTorch() }
        captureSessionManager?.stop()
    }

    // MARK: - Setups

    private func setupViews() {
        videoPreviewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(videoPreviewLayer)
        view.addSubview(rectView)

        let topBar = UIStackView(arrangedSubviews: [cancelButton, UIView(), torchButton, autoScanButton])
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.spacing = 10
        topBar.alignment = .center
        torchButton.isHidden = !(configuration.behavior.showsTorchButton && CaptureSession.current.isTorchAvailable)
        autoScanButton.isHidden = !configuration.behavior.showsAutoScanToggle
        view.addSubview(topBar)

        hintContainer.contentView.addSubview(hintLabel)
        hintContainer.isHidden = !configuration.behavior.showsHints
        hintContainer.isUserInteractionEnabled = false
        view.addSubview(hintContainer)

        shutterPlatter.contentView.addSubview(shutterButton)
        view.addSubview(shutterPlatter)
        view.addSubview(activityIndicator)

        let margins = view.safeAreaLayoutGuide
        let shutterSize = appearance.shutterButtonSize
        let platterInset: CGFloat = 8

        NSLayoutConstraint.activate([
            rectView.topAnchor.constraint(equalTo: view.topAnchor),
            rectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            topBar.topAnchor.constraint(equalTo: margins.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 16),
            topBar.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: -16),

            hintContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 16),
            hintContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintContainer.widthAnchor.constraint(lessThanOrEqualTo: margins.widthAnchor, constant: -48),
            hintLabel.topAnchor.constraint(equalTo: hintContainer.contentView.topAnchor, constant: 10),
            hintLabel.bottomAnchor.constraint(equalTo: hintContainer.contentView.bottomAnchor, constant: -10),
            hintLabel.leadingAnchor.constraint(equalTo: hintContainer.contentView.leadingAnchor, constant: 18),
            hintLabel.trailingAnchor.constraint(equalTo: hintContainer.contentView.trailingAnchor, constant: -18),

            shutterPlatter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterPlatter.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -16),
            shutterPlatter.widthAnchor.constraint(equalToConstant: shutterSize + platterInset * 2),
            shutterPlatter.heightAnchor.constraint(equalToConstant: shutterSize + platterInset * 2),
            shutterButton.centerXAnchor.constraint(equalTo: shutterPlatter.contentView.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: shutterPlatter.contentView.centerYAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: shutterSize),
            shutterButton.heightAnchor.constraint(equalToConstant: shutterSize),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func updateTorchButton() {
        let icons = appearance.icons
        torchButton.configuration = Glass.configuration(image: icons.image(isTorchOn ? icons.torchOn : icons.torchOff), title: nil, isActive: isTorchOn, appearance: appearance)
        torchButton.accessibilityValue = isTorchOn ? "1" : "0"
    }

    private func updateAutoScanButton() {
        let isOn = CaptureSession.current.isAutoScanEnabled
        let icons = appearance.icons
        autoScanButton.configuration = Glass.configuration(image: icons.image(isOn ? icons.autoScan : icons.manualScan),
                                                           title: isOn ? strings.autoScanOn : strings.autoScanOff,
                                                           isActive: false,
                                                           appearance: appearance)
    }

    private func updateHint(isDocumentDetected: Bool) {
        self.isDocumentDetected = isDocumentDetected
        let text: String
        if !isDocumentDetected {
            text = strings.hintSearching
        } else {
            text = CaptureSession.current.isAutoScanEnabled ? strings.hintHoldStill : strings.hintManual
        }
        guard hintLabel.text != text else { return }
        UIView.transition(with: hintLabel, duration: 0.2, options: .transitionCrossDissolve) {
            self.hintLabel.text = text
        }
    }

    // MARK: - Tap to Focus

    /// Called when the AVCaptureDevice detects that the subject area has changed significantly. When it's called, we reset the focus so the camera is no longer out of focus.
    @objc private func subjectAreaDidChange() {
        try? CaptureSession.current.resetFocusToAuto()
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: true)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard configuration.behavior.isTapToFocusEnabled,
              captureSessionManager != nil,
              let touch = touches.first else { return }
        let touchPoint = touch.location(in: view)
        let convertedTouchPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)

        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: false)

        let focusRectangle = FocusRectangleView(touchPoint: touchPoint, color: appearance.focusIndicatorColor)
        view.insertSubview(focusRectangle, aboveSubview: rectView)
        self.focusRectangle = focusRectangle

        try? CaptureSession.current.setFocusPointToTapPoint(convertedTouchPoint)
    }

    // MARK: - Actions

    @objc private func captureImage() {
        guard let captureSessionManager = captureSessionManager else {
            (navigationController as? ImageScannerController)?.fail(with: ImageScannerControllerError.inputDevice)
            return
        }
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager.capturePhoto()
    }

    @objc private func toggleTorch() {
        isTorchOn = CaptureSession.current.setTorch(on: !isTorchOn)
        updateTorchButton()
    }

    @objc private func toggleAutoScan() {
        CaptureSession.current.isAutoScanEnabled.toggle()
        if configuration.behavior.isHapticFeedbackEnabled { UISelectionFeedbackGenerator().selectionChanged() }
        updateAutoScanButton()
        updateHint(isDocumentDetected: isDocumentDetected)
    }

    @objc private func cancelImageScannerController() {
        (navigationController as? ImageScannerController)?.cancel()
    }
}

extension ScannerViewController: RectangleDetectionDelegateProtocol {

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true
        (navigationController as? ImageScannerController)?.fail(with: error)
    }

    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        shutterButton.isUserInteractionEnabled = false
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withRect rect: Rectangle?) {
        activityIndicator.stopAnimating()
        if configuration.behavior.isHapticFeedbackEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        (navigationController as? ImageScannerController)?.showProcessingStep(for: picture, rect: rect)
        shutterButton.isUserInteractionEnabled = true
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectRect rect: Rectangle?, _ imageSize: CGSize) {
        guard let rect = rect else {
            // If no rect has been detected, we remove the currently displayed on on the rectView.
            rectView.removeRectangle()
            updateHint(isDocumentDetected: false)
            return
        }

        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: rectView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)
        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: rectView.bounds)

        let transformedRect = rect.applyTransforms([scaleTransform, rotationTransform, translationTransform])
        rectView.drawRectangle(rect: transformedRect, animated: true)
        updateHint(isDocumentDetected: true)
    }
}

// MARK: - Two-sided flip prompt

extension ScannerViewController {

    /// A glass card asking to flip the document; any tap dismisses it and resumes scanning.
    private func displayFlipOverlay() {
        CaptureSession.current.isEditing = true

        let overlay = UIControl()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        overlay.addTarget(self, action: #selector(dismissFlipOverlay(_:)), for: .touchUpInside)

        let card = Glass.background(appearance, cornerRadius: 32)
        card.isUserInteractionEnabled = false

        let icon = UIImageView(image: appearance.icons.image(appearance.icons.flip))
        icon.tintColor = appearance.tintColor
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .medium)
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = strings.flipPrompt
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = appearance.controlForegroundColor
        label.textAlignment = .center
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        overlay.addSubview(card)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            card.widthAnchor.constraint(equalTo: overlay.widthAnchor, multiplier: 0.8),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -28),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -24)
        ])

        overlay.alpha = 0
        UIView.animate(withDuration: 0.25) { overlay.alpha = 1 }
    }

    @objc private func dismissFlipOverlay(_ overlay: UIControl) {
        UIView.animate(withDuration: 0.2, animations: { overlay.alpha = 0 }, completion: { _ in
            overlay.removeFromSuperview()
            CaptureSession.current.isEditing = false
        })
    }
}
