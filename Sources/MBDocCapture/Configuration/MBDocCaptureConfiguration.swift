//
//  MBDocCaptureConfiguration.swift
//  MBDocCapture
//
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit

/// Everything you can tweak in the scanning experience: look, behaviour, detection tuning and texts.
///
/// Start from ``default`` and change only what you need:
///
/// ```swift
/// var configuration = MBDocCaptureConfiguration()
/// configuration.appearance.tintColor = .systemPink
/// configuration.behavior.scanMode = .twoSided
/// configuration.strings.cancel = "Close"
///
/// let scanner = ImageScannerController(configuration: configuration, delegate: self)
/// ```
public struct MBDocCaptureConfiguration {

    /// Colors, sizes, icons and the Liquid Glass switch.
    public var appearance = Appearance()

    /// Which steps, buttons and features are enabled.
    public var behavior = Behavior()

    /// Tuning of the rectangle detection, auto scan and enhancement filter.
    public var detection = Detection()

    /// Every user-facing text. Defaults are localized (English and French are bundled).
    public var strings = Strings()

    /// The stock configuration.
    public static var `default`: MBDocCaptureConfiguration { MBDocCaptureConfiguration() }

    public init() {}
}

// MARK: - Appearance

extension MBDocCaptureConfiguration {

    /// Visual customization of the scanner.
    public struct Appearance {

        /// Uses Liquid Glass for floating controls on iOS 26 and later.
        /// When `false`, or on earlier systems, controls use a translucent material blur instead.
        public var usesLiquidGlass = true

        /// The interface style forced on the scanner. Camera UIs read best in `.dark`; use `.unspecified` to follow the system.
        public var interfaceStyle: UIUserInterfaceStyle = .dark

        /// Accent color: active toggles (flashlight, enhance), prominent buttons and navigation bar items.
        public var tintColor: UIColor = .systemYellow

        /// Color of icons and labels drawn on top of glass controls.
        public var controlForegroundColor: UIColor = .white

        /// Background behind the camera preview and the captured images.
        public var backgroundColor: UIColor = .black

        /// Outline color of the live detected document.
        public var detectionStrokeColor: UIColor = .white

        /// Fill color of the live detected document.
        public var detectionFillColor: UIColor = UIColor.white.withAlphaComponent(0.25)

        /// Outline width of the detected / editable document, in points.
        public var detectionLineWidth: CGFloat = 2

        /// Outline color of the quadrilateral on the corner adjustment screen.
        public var editStrokeColor: UIColor = .white

        /// Dimming color applied outside the quadrilateral on the corner adjustment screen.
        public var editMaskColor: UIColor = UIColor.black.withAlphaComponent(0.6)

        /// Color of the draggable corner handles.
        public var cornerHandleColor: UIColor = .white

        /// Diameter of the corner handles, in points.
        public var cornerHandleSize: CGFloat = 22

        /// Diameter of the magnifier shown while dragging a corner, in points.
        public var magnifierSize: CGFloat = 96

        /// Zoom factor of the magnifier.
        public var magnifierZoom: CGFloat = 2.5

        /// Color of the tap-to-focus indicator.
        public var focusIndicatorColor: UIColor = .systemYellow

        /// Color of the shutter button.
        public var shutterButtonColor: UIColor = .white

        /// Diameter of the shutter button, in points.
        public var shutterButtonSize: CGFloat = 72

        /// Font of the hint shown above the camera preview.
        public var hintFont: UIFont = .preferredFont(forTextStyle: .subheadline)

        /// SF Symbols names (or your own asset names, see ``Icons``) used by the buttons.
        public var icons = Icons()

        public init() {}
    }

    /// Images used by the scanner buttons.
    ///
    /// Each value is an SF Symbol name by default. Provide a `UIImage` with the matching `custom…` property to use your own artwork.
    public struct Icons {
        public var cancel = "xmark"
        public var torchOff = "flashlight.off.fill"
        public var torchOn = "flashlight.on.fill"
        public var autoScan = "a.circle"
        public var manualScan = "hand.tap"
        public var enhance = "wand.and.stars"
        public var rotate = "rotate.right"
        public var flip = "arrow.triangle.2.circlepath"

        /// Overrides keyed by SF Symbol name above. Example: `icons.custom["xmark"] = UIImage(named: "close")`.
        public var custom: [String: UIImage] = [:]

        public init() {}

        func image(_ name: String) -> UIImage? {
            custom[name] ?? UIImage(systemName: name) ?? UIImage(systemName: "questionmark")
        }
    }
}

// MARK: - Behavior

extension MBDocCaptureConfiguration {

    /// How many faces of the document are scanned in one session.
    public enum ScanMode {
        /// One page, delivered through `imageScannerController(_:didFinishScanningWithResults:)`.
        case singlePage
        /// Front then back, delivered through `imageScannerController(_:didFinishScanningWithPage1Results:andPage2Results:)`.
        case twoSided
    }

    /// Feature switches.
    public struct Behavior {

        /// Single page or front + back.
        public var scanMode: ScanMode = .singlePage

        /// Whether auto scan (capture once the document is stable) is on when the scanner opens.
        public var isAutoScanEnabled = true

        /// Shows the Auto / Manual toggle.
        public var showsAutoScanToggle = true

        /// Shows the flashlight button (hidden automatically on devices without a torch).
        public var showsTorchButton = true

        /// Shows the guidance hint ("Position the document in view", "Hold still…").
        public var showsHints = true

        /// Lets the user tap the preview to focus.
        public var isTapToFocusEnabled = true

        /// Plays haptics on capture and corner drag.
        public var isHapticFeedbackEnabled = true

        /// Shows the corner adjustment step. When `false`, the detected rectangle (or the full image) is used as is.
        public var showsEditStep = true

        /// Shows the review step. When `false`, results are delivered right after the edit step.
        public var showsReviewStep = true

        /// Offers the black & white "enhanced" version on the review screen.
        public var isEnhancementAvailable = true

        /// Whether the enhanced image is selected by default on the review screen.
        public var prefersEnhancedImageByDefault = false

        /// Offers the rotate button on the review screen.
        public var isRotationAvailable = true

        /// Lets the user dismiss the scanner with a swipe down when presented as a sheet.
        public var allowsSwipeToDismiss = false

        public init() {}
    }
}

// MARK: - Detection

extension MBDocCaptureConfiguration {

    /// Fine tuning of the detection engine. The defaults work well for paper documents; change them only if needed.
    public struct Detection {

        /// Number of consecutive stable frames required before an auto scan fires. Lower is faster, higher is more careful.
        public var autoScanStabilityFrames = 35

        /// Maximum corner movement, in pixels, for a frame to count as stable during auto scan.
        public var autoScanPrecision: CGFloat = 6

        /// Distance, in pixels, under which two detected rectangles are considered the same document.
        public var matchingThreshold: CGFloat = 40

        /// Luminance range of the enhancement filter: below the lower bound becomes black, above the upper bound becomes white.
        public var enhancementRange: ClosedRange<CGFloat> = 0.25...0.75

        public init() {}
    }
}

// MARK: - Strings

extension MBDocCaptureConfiguration {

    /// User-facing texts. Every default comes from the bundled `Localizable.strings` (English, French).
    public struct Strings {
        public var cancel = localized("mbdoccapture.cancel_button", "Cancel")
        public var next = localized("mbdoccapture.next_button", "Next")
        public var done = localized("mbdoccapture.done_button", "Done")
        public var editTitle = localized("mbdoccapture.scan_edit_title", "Adjust Corners")
        public var reviewTitle = localized("mbdoccapture.scan_review_title", "Review")
        public var flipPrompt = localized("mbdoccapture.document_capture_flip", "Flip your document, then tap anywhere to scan the other side.")
        public var hintSearching = localized("mbdoccapture.hint_searching", "Position the document in view")
        public var hintHoldStill = localized("mbdoccapture.hint_hold_still", "Hold still…")
        public var hintManual = localized("mbdoccapture.hint_manual", "Tap the shutter to scan")
        public var autoScanOn = localized("mbdoccapture.auto_scan_on", "Auto")
        public var autoScanOff = localized("mbdoccapture.auto_scan_off", "Manual")
        public var torch = localized("mbdoccapture.torch", "Flashlight")
        public var shutter = localized("mbdoccapture.shutter", "Scan document")
        public var enhance = localized("mbdoccapture.enhance", "Enhance")
        public var rotate = localized("mbdoccapture.rotate", "Rotate")

        public init() {}

        static func localized(_ key: String, _ value: String) -> String {
            NSLocalizedString(key, tableName: nil, bundle: .module, value: value, comment: "")
        }
    }
}
