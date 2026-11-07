//
//  ImageScannerController.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit
import AVFoundation

/// The methods your delegate implements to receive the scanner's results.
///
/// Every method is called on the main thread. Your implementation is responsible for dismissing the scanner.
public protocol ImageScannerControllerDelegate: AnyObject {

    /// The user scanned a document (``MBDocCaptureConfiguration/ScanMode/singlePage``).
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults)

    /// The user scanned both faces of a document (``MBDocCaptureConfiguration/ScanMode/twoSided``).
    /// Has a default implementation that does nothing, so only implement it if you use two-sided scanning.
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithPage1Results page1Results: ImageScannerResults, andPage2Results page2Results: ImageScannerResults)

    /// The user tapped Cancel.
    func imageScannerControllerDidCancel(_ scanner: ImageScannerController)

    /// Something went wrong: camera permission denied, no camera, capture failure… See ``ImageScannerControllerError``.
    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error)
}

public extension ImageScannerControllerDelegate {
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithPage1Results page1Results: ImageScannerResults, andPage2Results page2Results: ImageScannerResults) {}
}

/// A view controller that manages the whole document scanning flow. Present it modally.
///
/// The flow has up to three screens, each of which can be turned off in ``MBDocCaptureConfiguration/Behavior``:
/// 1. **Scan** — live camera with document detection and auto capture.
/// 2. **Adjust** — drag the four corners to fine tune the crop.
/// 3. **Review** — rotate, toggle the enhanced black & white version, confirm.
///
/// ```swift
/// let scanner = ImageScannerController(delegate: self)
/// present(scanner, animated: true)
/// ```
///
/// Prefer closures or async/await? See ``init(image:configuration:completion:)`` and ``scan(from:image:configuration:)``.
public final class ImageScannerController: UINavigationController {

    /// The object that receives the results.
    public weak var imageScannerDelegate: ImageScannerControllerDelegate?

    /// The configuration the scanner was created with.
    public private(set) var configuration: MBDocCaptureConfiguration = .default

    /// Scans the front and the back of a document. Prefer setting ``MBDocCaptureConfiguration/Behavior/scanMode``.
    public var shouldScanTwoFaces: Bool {
        get { CaptureSession.current.isScanningTwoFacedDocument }
        set {
            configuration.behavior.scanMode = newValue ? .twoSided : .singlePage
            CaptureSession.current.isScanningTwoFacedDocument = newValue
        }
    }

    /// Keeps the closure adapter alive (the delegate is weak).
    private var completionBridge: CompletionBridge?

    /// A dimmed view flashed when the shutter fires.
    private let blackFlashView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Life Cycle

    /// Creates a scanner.
    ///
    /// - Parameters:
    ///   - image: Pass an existing image (e.g. picked from the photo library) to skip the camera and start at the adjust step.
    ///   - configuration: Appearance, behavior, detection and texts. Defaults to ``MBDocCaptureConfiguration/default``.
    ///   - delegate: The object that receives the results.
    public init(image: UIImage? = nil, configuration: MBDocCaptureConfiguration = .default, delegate: ImageScannerControllerDelegate? = nil) {
        self.configuration = configuration
        CaptureSession.current.reset(with: configuration)
        super.init(rootViewController: ScannerViewController(configuration: configuration))
        self.imageScannerDelegate = delegate
        commonInit(image: image)
    }

    /// Creates a scanner that reports through a single closure instead of a delegate.
    ///
    /// The closure receives one result (single page) or two (front, back). Cancelling yields `CancellationError`.
    /// The scanner dismisses itself before calling `completion`.
    public convenience init(image: UIImage? = nil, configuration: MBDocCaptureConfiguration = .default, completion: @escaping (Result<[ImageScannerResults], Error>) -> Void) {
        let bridge = CompletionBridge(completion: completion)
        self.init(image: image, configuration: configuration, delegate: bridge)
        completionBridge = bridge
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit(image: UIImage?) {
        let appearance = configuration.appearance
        applyInterfaceStyle()
        view.backgroundColor = appearance.backgroundColor
        view.tintColor = appearance.tintColor
        navigationBar.tintColor = appearance.controlForegroundColor
        toolbar.tintColor = appearance.controlForegroundColor
        modalPresentationStyle = .fullScreen
        isModalInPresentation = !configuration.behavior.allowsSwipeToDismiss

        view.addSubview(blackFlashView)
        NSLayoutConstraint.activate([
            blackFlashView.topAnchor.constraint(equalTo: view.topAnchor),
            blackFlashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blackFlashView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blackFlashView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // If an image was passed in by the host app, skip the camera.
        guard let image = image?.normalized() else { return }
        var detectedRect: Rectangle?
        if let ciImage = CIImage(image: image) {
            // Core Image works bottom-left origin; the edit step expects UIKit (top-left) coordinates.
            detectedRect = CIRectangleDetector.rectangle(forImage: ciImage)?.toCartesian(withHeight: image.size.height)
            detectedRect?.reorganize()
        }
        showProcessingStep(for: image, rect: detectedRect, rotateImage: false, replacingStack: true)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // SwiftUI hosting resets the override set at init time to its own color scheme: apply it again.
        applyInterfaceStyle()
    }

    private func applyInterfaceStyle() {
        let style = configuration.appearance.interfaceStyle
        if #available(iOS 17.0, *) {
            if style == .unspecified {
                traitOverrides.remove(UITraitUserInterfaceStyle.self)
            } else {
                traitOverrides.userInterfaceStyle = style
            }
        } else {
            overrideUserInterfaceStyle = style
        }
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }
    override public var childForStatusBarStyle: UIViewController? { nil }
    override public var childForStatusBarHidden: UIViewController? { nil }
    override public var prefersStatusBarHidden: Bool { true }

    // MARK: - Flow

    func flashToBlack() {
        view.bringSubviewToFront(blackFlashView)
        blackFlashView.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.blackFlashView.isHidden = true
        }
    }

    /// Goes to the adjust step, or straight to review/finish when the adjust step is turned off.
    func showProcessingStep(for image: UIImage, rect: Rectangle?, rotateImage: Bool = true, replacingStack: Bool = false) {
        if configuration.behavior.showsEditStep {
            let editViewController = EditScanViewController(image: image, rect: rect, rotateImage: rotateImage, configuration: configuration)
            replacingStack ? setViewControllers([editViewController], animated: false) : pushViewController(editViewController, animated: false)
            return
        }

        let orientedImage = rotateImage ? image.applyingPortraitOrientation() : image
        let rect = rect ?? Rectangle(rect: CGRect(origin: .zero, size: orientedImage.size))
        guard let results = ImageProcessor.process(image: orientedImage, rect: rect, configuration: configuration) else {
            fail(with: ImageScannerControllerError.ciImageCreation)
            return
        }
        showReviewStep(with: results, replacingStack: replacingStack)
    }

    /// Goes to the review step, or finishes directly when the review step is turned off.
    func showReviewStep(with results: ImageScannerResults, replacingStack: Bool = false) {
        guard configuration.behavior.showsReviewStep else {
            finish(with: results)
            return
        }
        let reviewViewController = ReviewViewController(results: results, configuration: configuration)
        replacingStack ? setViewControllers([reviewViewController], animated: false) : pushViewController(reviewViewController, animated: true)
    }

    /// Delivers the results, or loops back to the camera for the second face.
    func finish(with results: ImageScannerResults) {
        let session = CaptureSession.current
        guard session.isScanningTwoFacedDocument else {
            imageScannerDelegate?.imageScannerController(self, didFinishScanningWithResults: results)
            return
        }

        if let firstPageResults = session.firstScanResult {
            session.firstScanResult = nil
            imageScannerDelegate?.imageScannerController(self, didFinishScanningWithPage1Results: firstPageResults, andPage2Results: results)
        } else {
            session.firstScanResult = results
            if viewControllers.first is ScannerViewController {
                popToRootViewController(animated: true)
            } else {
                // Started from an image: the back side comes from the camera.
                setViewControllers([ScannerViewController(configuration: configuration)], animated: true)
            }
        }
    }

    func cancel() {
        imageScannerDelegate?.imageScannerControllerDidCancel(self)
    }

    func fail(with error: Error) {
        imageScannerDelegate?.imageScannerController(self, didFailWithError: error)
    }
}

// MARK: - Async / await

extension ImageScannerController {

    /// Presents a scanner and waits for the user to finish.
    ///
    /// ```swift
    /// let pages = try await ImageScannerController.scan(from: self)
    /// imageView.image = pages[0].preferredImage
    /// ```
    ///
    /// - Returns: One result (single page) or two (front, back).
    /// - Throws: `CancellationError` if the user cancels, or an ``ImageScannerControllerError``.
    @MainActor
    public static func scan(from presenter: UIViewController, image: UIImage? = nil, configuration: MBDocCaptureConfiguration = .default) async throws -> [ImageScannerResults] {
        try await withCheckedThrowingContinuation { continuation in
            let scanner = ImageScannerController(image: image, configuration: configuration) { result in
                continuation.resume(with: result)
            }
            presenter.present(scanner, animated: true)
        }
    }
}

/// Adapts the delegate to a single result closure.
private final class CompletionBridge: ImageScannerControllerDelegate {
    private var completion: ((Result<[ImageScannerResults], Error>) -> Void)?

    init(completion: @escaping (Result<[ImageScannerResults], Error>) -> Void) {
        self.completion = completion
    }

    private func complete(_ scanner: ImageScannerController, with result: Result<[ImageScannerResults], Error>) {
        // Called once, after the dismissal so the presenter is ready for what comes next.
        guard let completion = completion else { return }
        self.completion = nil
        scanner.dismiss(animated: true) { completion(result) }
    }

    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults) {
        complete(scanner, with: .success([results]))
    }

    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithPage1Results page1Results: ImageScannerResults, andPage2Results page2Results: ImageScannerResults) {
        complete(scanner, with: .success([page1Results, page2Results]))
    }

    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        complete(scanner, with: .failure(CancellationError()))
    }

    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
        complete(scanner, with: .failure(error))
    }
}

// MARK: - Results

/// The output of a scan.
public struct ImageScannerResults {

    /// The original image taken by the user, prior to the cropping applied.
    public var originalImage: UIImage

    /// The deskewed and cropped original image using the detected rectangle, without any filters.
    public var scannedImage: UIImage

    /// The enhanced image (grayscale, high contrast). `nil` when enhancement is turned off or failed.
    public var enhancedImage: UIImage?

    /// Whether the user chose the enhanced image on the review screen. `enhancedImage` may be available even when `false` (e.g. for OCR).
    public var doesUserPreferEnhancedImage: Bool

    /// The rectangle, in `originalImage` coordinates, used to generate `scannedImage`.
    public var detectedRectangle: Rectangle

    /// The image the user picked: `enhancedImage` when preferred and available, `scannedImage` otherwise.
    public var preferredImage: UIImage {
        doesUserPreferEnhancedImage ? (enhancedImage ?? scannedImage) : scannedImage
    }

    public init(originalImage: UIImage, scannedImage: UIImage, enhancedImage: UIImage?, doesUserPreferEnhancedImage: Bool, detectedRectangle: Rectangle) {
        self.originalImage = originalImage
        self.scannedImage = scannedImage
        self.enhancedImage = enhancedImage
        self.doesUserPreferEnhancedImage = doesUserPreferEnhancedImage
        self.detectedRectangle = detectedRectangle
    }
}
