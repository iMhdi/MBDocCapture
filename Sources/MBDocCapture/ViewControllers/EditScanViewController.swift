//
//  EditScanViewController.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit
import AVFoundation

/// Lets the user drag the four corners of the detected document, with a magnifier under the finger.
final class EditScanViewController: UIViewController {

    private let configuration: MBDocCaptureConfiguration

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.image = image
        imageView.backgroundColor = configuration.appearance.backgroundColor
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var rectView: RectangleView = {
        let rectView = RectangleView(appearance: configuration.appearance)
        rectView.editable = true
        rectView.translatesAutoresizingMaskIntoConstraints = false
        return rectView
    }()

    /// The image the rectangle was detected on.
    private let image: UIImage

    /// The detected rectangle that can be edited by the user. Uses the image's coordinates.
    private var rect: Rectangle

    private var zoomGestureController: ZoomGestureController!

    private var rectViewWidthConstraint = NSLayoutConstraint()
    private var rectViewHeightConstraint = NSLayoutConstraint()

    // MARK: - Life Cycle

    init(image: UIImage, rect: Rectangle?, rotateImage: Bool = true, configuration: MBDocCaptureConfiguration) {
        self.image = rotateImage ? image.applyingPortraitOrientation() : image
        self.rect = rect ?? EditScanViewController.defaultRectangle(forImage: self.image)
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = configuration.appearance.backgroundColor
        title = configuration.strings.editTitle

        view.addSubview(imageView)
        view.addSubview(rectView)
        setupConstraints()

        let nextTitle = configuration.behavior.showsReviewStep ? configuration.strings.next : configuration.strings.done
        let nextButton = UIBarButtonItem(title: nextTitle, style: .done, target: self, action: #selector(pushReviewController))
        nextButton.tintColor = configuration.appearance.tintColor
        navigationItem.rightBarButtonItem = nextButton

        // Root of the stack when started from an image: give a way out.
        if navigationController?.viewControllers.first === self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: configuration.strings.cancel, style: .plain, target: self, action: #selector(cancel))
        }

        zoomGestureController = ZoomGestureController(image: image, rectView: rectView, configuration: configuration)
        let touchDown = UILongPressGestureRecognizer(target: zoomGestureController, action: #selector(zoomGestureController.handle(pan:)))
        touchDown.minimumPressDuration = 0
        view.addGestureRecognizer(touchDown)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustRectViewConstraints()
        displayRect()
    }

    private func setupConstraints() {
        rectViewWidthConstraint = rectView.widthAnchor.constraint(equalToConstant: 0.0)
        rectViewHeightConstraint = rectView.heightAnchor.constraint(equalToConstant: 0.0)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            imageView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
            imageView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            rectView.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            rectView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            rectViewWidthConstraint,
            rectViewHeightConstraint
        ])
    }

    // MARK: - Actions

    @objc private func cancel() {
        (navigationController as? ImageScannerController)?.cancel()
    }

    @objc func pushReviewController() {
        guard let scanner = navigationController as? ImageScannerController else { return }
        guard let rect = rectView.rect else {
            scanner.fail(with: ImageScannerControllerError.ciImageCreation)
            return
        }

        let scaledRect = rect.scale(rectView.bounds.size, image.size)
        self.rect = scaledRect

        guard let results = ImageProcessor.process(image: image, rect: scaledRect, configuration: configuration) else {
            scanner.fail(with: ImageScannerControllerError.ciImageCreation)
            return
        }
        scanner.showReviewStep(with: results)
    }

    private func displayRect() {
        let imageFrameSize = CGSize(width: rectViewWidthConstraint.constant, height: rectViewHeightConstraint.constant)
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: image.size, aspectFillInSize: imageFrameSize)
        rectView.drawRectangle(rect: rect.applyTransforms([scaleTransform]), animated: false)
    }

    /// Lines the rectView up with the image actually displayed (aspect fit) by the imageView.
    private func adjustRectViewConstraints() {
        let frame = AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
        rectViewWidthConstraint.constant = frame.size.width
        rectViewHeightConstraint.constant = frame.size.height
    }

    /// A centered rectangle covering the middle third of the image, used when nothing was detected.
    private static func defaultRectangle(forImage image: UIImage) -> Rectangle {
        let size = image.size
        return Rectangle(rect: CGRect(x: size.width / 3, y: size.height / 3, width: size.width / 3, height: size.height / 3))
    }
}
