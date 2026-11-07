# ``MBDocCapture``

A customizable document scanner with live detection, auto capture, perspective correction and a Liquid Glass interface.

## Overview

MBDocCapture guides the user through up to three screens:

1. **Scan** — the camera detects the document and captures it automatically once it is stable, or with the shutter.
2. **Adjust** — the user drags the four corners, helped by a magnifier.
3. **Review** — the user rotates the result, toggles the black & white enhancement and confirms.

@Row {
    @Column { ![The scan screen](scan.png) }
    @Column { ![The adjust screen](adjust.png) }
    @Column { ![The review screen](review.png) }
}

On iOS 26 and later the floating controls use Liquid Glass; earlier systems get a material blur. Everything — colors, icons, texts, steps, detection thresholds — is configured through ``MBDocCaptureConfiguration``.

## Topics

### Essentials

- <doc:GettingStarted>
- ``ImageScannerController``
- ``ImageScannerControllerDelegate``
- ``ImageScannerResults``

### SwiftUI and concurrency

- <doc:SwiftUIAndConcurrency>
- ``DocumentScanner``
- ``SwiftUICore/View/documentScanner(isPresented:image:configuration:onCompletion:)``

### Customization

- <doc:Customization>
- ``MBDocCaptureConfiguration``

### Errors

- ``ImageScannerControllerError``

### Geometry

- ``Rectangle``
