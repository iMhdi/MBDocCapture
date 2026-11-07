# SwiftUI and Concurrency

Present the scanner from SwiftUI, with async/await, or with a single closure.

## SwiftUI

The ``SwiftUICore/View/documentScanner(isPresented:image:configuration:onCompletion:)`` modifier presents the scanner full screen and dismisses it when the user is done:

```swift
struct ContentView: View {
    @State private var isScanning = false
    @State private var pages: [ImageScannerResults] = []

    var body: some View {
        Button("Scan") { isScanning = true }
            .documentScanner(isPresented: $isScanning) { result in
                switch result {
                case .success(let pages): self.pages = pages
                case .failure(is CancellationError): break
                case .failure(let error): print(error)
                }
            }
    }
}
```

For custom presentations, embed ``DocumentScanner`` yourself. It does not dismiss itself: hide it from `onCompletion`.

## async/await

``ImageScannerController/scan(from:image:configuration:)`` presents a scanner and returns when the user is done:

```swift
let pages = try await ImageScannerController.scan(from: self)
```

## Closures

``ImageScannerController/init(image:configuration:completion:)`` reports through one closure, after dismissing itself:

```swift
let scanner = ImageScannerController { result in
    if case .success(let pages) = result { save(pages) }
}
present(scanner, animated: true)
```

## Result shape

All three APIs return an array: one ``ImageScannerResults`` for a single page, two (front, back) in ``MBDocCaptureConfiguration/ScanMode/twoSided`` mode. Cancelling throws `CancellationError`; other failures are ``ImageScannerControllerError`` values.
