//
//  ReviewViewController.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit

/// Shows the cropped document; the user can rotate it, toggle the enhanced version and confirm.
final class ReviewViewController: UIViewController {

    private let configuration: MBDocCaptureConfiguration
    private var rotationAngle = Measurement<UnitAngle>(value: 0, unit: .degrees)
    private var isCurrentlyDisplayingEnhancedImage: Bool
    private let results: ImageScannerResults

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerCurve = .continuous
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        return imageView
    }()

    private lazy var enhanceButton: UIBarButtonItem = {
        let icons = configuration.appearance.icons
        let button = UIBarButtonItem(image: icons.image(icons.enhance), style: .plain, target: self, action: #selector(toggleEnhancedImage))
        button.accessibilityLabel = configuration.strings.enhance
        return button
    }()

    private lazy var rotateButton: UIBarButtonItem = {
        let icons = configuration.appearance.icons
        let button = UIBarButtonItem(image: icons.image(icons.rotate), style: .plain, target: self, action: #selector(rotateImage))
        button.accessibilityLabel = configuration.strings.rotate
        return button
    }()

    // MARK: - Life Cycle

    init(results: ImageScannerResults, configuration: MBDocCaptureConfiguration) {
        self.results = results
        self.configuration = configuration
        self.isCurrentlyDisplayingEnhancedImage = results.doesUserPreferEnhancedImage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    private var enhancedImageIsAvailable: Bool { results.enhancedImage != nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = configuration.appearance.backgroundColor
        title = configuration.strings.reviewTitle

        view.addSubview(imageView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            imageView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
            imageView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16)
        ])

        let doneButton = UIBarButtonItem(title: configuration.strings.done, style: .done, target: self, action: #selector(finishScan))
        doneButton.tintColor = configuration.appearance.tintColor
        navigationItem.rightBarButtonItem = doneButton

        if navigationController?.viewControllers.first === self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: configuration.strings.cancel, style: .plain, target: self, action: #selector(cancel))
        }

        var items = [UIBarButtonItem]()
        if enhancedImageIsAvailable { items.append(enhanceButton) }
        if configuration.behavior.isRotationAvailable { items.append(rotateButton) }
        toolbarItems = items.isEmpty ? nil : [.flexibleSpace()] + items.flatMap { [$0, .flexibleSpace()] }

        reloadImage()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(toolbarItems == nil, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    // MARK: - Actions

    private func reloadImage() {
        let image = isCurrentlyDisplayingEnhancedImage ? (results.enhancedImage ?? results.scannedImage) : results.scannedImage
        imageView.image = image.rotated(by: rotationAngle) ?? image
        enhanceButton.tintColor = isCurrentlyDisplayingEnhancedImage ? configuration.appearance.tintColor : configuration.appearance.controlForegroundColor
        enhanceButton.accessibilityValue = isCurrentlyDisplayingEnhancedImage ? "1" : "0"
    }

    @objc private func toggleEnhancedImage() {
        guard enhancedImageIsAvailable else { return }
        isCurrentlyDisplayingEnhancedImage.toggle()
        if configuration.behavior.isHapticFeedbackEnabled { UISelectionFeedbackGenerator().selectionChanged() }
        UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve) { self.reloadImage() }
    }

    @objc private func rotateImage() {
        rotationAngle.value = (rotationAngle.value + 90).truncatingRemainder(dividingBy: 360)
        reloadImage()
    }

    @objc private func cancel() {
        (navigationController as? ImageScannerController)?.cancel()
    }

    @objc private func finishScan() {
        guard let scanner = navigationController as? ImageScannerController else { return }
        var newResults = results
        newResults.scannedImage = results.scannedImage.rotated(by: rotationAngle) ?? results.scannedImage
        newResults.enhancedImage = results.enhancedImage.map { $0.rotated(by: rotationAngle) ?? $0 }
        newResults.doesUserPreferEnhancedImage = isCurrentlyDisplayingEnhancedImage
        scanner.finish(with: newResults)
    }
}
