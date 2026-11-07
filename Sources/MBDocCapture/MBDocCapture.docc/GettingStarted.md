# Getting Started

Add the package, allow camera access and present a scanner.

## Add the package

In Xcode choose **File ▸ Add Package Dependencies…** and enter `https://github.com/iMhdi/MBDocCapture.git`, or add it to your `Package.swift`:

```swift
.package(url: "https://github.com/iMhdi/MBDocCapture.git", from: "1.0.0")
```

## Allow camera access

Add `NSCameraUsageDescription` to your app's `Info.plist`. Without it, the system terminates your app the first time the scanner opens the camera. If the user denies access, the scanner reports ``ImageScannerControllerError/authorization``.

## Present a scanner

Create an ``ImageScannerController``, give it a delegate and present it:

```swift
let scanner = ImageScannerController(delegate: self)
present(scanner, animated: true)
```

Implement ``ImageScannerControllerDelegate``. Your implementation dismisses the scanner:

```swift
func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults) {
    imageView.image = results.preferredImage
    scanner.dismiss(animated: true)
}

func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
    scanner.dismiss(animated: true)
}

func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
    scanner.dismiss(animated: true)
}
```

## Use the results

``ImageScannerResults/preferredImage`` is the image the user picked on the review screen. ``ImageScannerResults/scannedImage`` is always the color crop, and ``ImageScannerResults/enhancedImage`` the black & white version, useful for OCR even when the user preferred the color one.

## Scan both sides

Set ``MBDocCaptureConfiguration/Behavior/scanMode`` to ``MBDocCaptureConfiguration/ScanMode/twoSided``. After the front is confirmed the user is asked to flip the document, and both results arrive through ``ImageScannerControllerDelegate/imageScannerController(_:didFinishScanningWithPage1Results:andPage2Results:)``.

## Crop an existing image

Pass an image to ``ImageScannerController/init(image:configuration:delegate:)`` to skip the camera. The document is detected when possible, and the flow starts at the adjust step.

## Try it in the Simulator

The Simulator has no camera, so the scanner reports ``ImageScannerControllerError/inputDevice``. Use an existing image there, or run on a device.
