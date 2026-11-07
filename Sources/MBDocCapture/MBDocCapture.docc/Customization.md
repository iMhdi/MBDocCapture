# Customization

Tailor the look, the flow, the detection and the texts of the scanner.

## Overview

Create a ``MBDocCaptureConfiguration``, change what you need, and pass it to the scanner. Every property has a sensible default.

```swift
var configuration = MBDocCaptureConfiguration()
configuration.appearance.tintColor = .systemPink
configuration.behavior.showsReviewStep = false
configuration.strings.hintSearching = "Show me a receipt"

let scanner = ImageScannerController(configuration: configuration, delegate: self)
```

## Appearance

``MBDocCaptureConfiguration/Appearance`` controls colors and sizes of the detection outline, corner handles, magnifier, shutter, focus indicator and hint.

``MBDocCaptureConfiguration/Appearance/usesLiquidGlass`` turns Liquid Glass on or off. It only takes effect on iOS 26 and later, and when the app is built with the iOS 26 SDK; otherwise controls use a material blur.

``MBDocCaptureConfiguration/Appearance/interfaceStyle`` defaults to `.dark`, which suits a camera interface. Use `.unspecified` to follow the system.

### Icons

Buttons use SF Symbols named in ``MBDocCaptureConfiguration/Icons``. Replace a name with another symbol, or provide your own image keyed by the symbol name:

```swift
configuration.appearance.icons.rotate = "rotate.left"
configuration.appearance.icons.custom["wand.and.stars"] = UIImage(named: "magic")
```

## Behavior

``MBDocCaptureConfiguration/Behavior`` decides which steps and controls appear:

- term ``MBDocCaptureConfiguration/Behavior/showsEditStep``: When `false`, the detected rectangle (or the whole image) is used without adjustment.
- term ``MBDocCaptureConfiguration/Behavior/showsReviewStep``: When `false`, results are delivered right after the adjust step.
- term ``MBDocCaptureConfiguration/Behavior/isAutoScanEnabled``: Initial state of auto capture; ``MBDocCaptureConfiguration/Behavior/showsAutoScanToggle`` lets the user switch it.
- term ``MBDocCaptureConfiguration/Behavior/isEnhancementAvailable``: Computes and offers the black & white version.

Turning off both the edit and review steps gives a one-tap scanner.

The scanner is presented full screen by default; set `modalPresentationStyle` on it before presenting to change that, and ``MBDocCaptureConfiguration/Behavior/allowsSwipeToDismiss`` to let a sheet be swiped away.

## Detection

``MBDocCaptureConfiguration/Detection`` tunes the engine. Lower ``MBDocCaptureConfiguration/Detection/autoScanStabilityFrames`` for a faster auto capture, raise ``MBDocCaptureConfiguration/Detection/autoScanPrecision`` to accept a shakier hand. ``MBDocCaptureConfiguration/Detection/enhancementRange`` sets the luminance window of the black & white filter.

## Texts and localization

``MBDocCaptureConfiguration/Strings`` holds every user-facing text. English and French ship with the package and are chosen automatically. Assign your own strings to support another language or change the wording; the button texts also serve as VoiceOver labels.
