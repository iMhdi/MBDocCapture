//
//  DocumentScanner.swift
//  MBDocCapture
//
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import SwiftUI

/// The scanner as a SwiftUI view. Most apps prefer the ``SwiftUICore/View/documentScanner(isPresented:image:configuration:onCompletion:)`` modifier.
///
/// The view does not dismiss itself: hide it from `onCompletion`.
///
/// ```swift
/// .fullScreenCover(isPresented: $isScanning) {
///     DocumentScanner { result in
///         isScanning = false
///         if case .success(let pages) = result { self.pages = pages }
///     }
///     .ignoresSafeArea()
/// }
/// ```
public struct DocumentScanner: UIViewControllerRepresentable {

    private let image: UIImage?
    private let configuration: MBDocCaptureConfiguration
    private let onCompletion: (Result<[ImageScannerResults], Error>) -> Void

    /// - Parameters:
    ///   - image: An existing image to crop instead of using the camera.
    ///   - configuration: Appearance, behavior, detection and texts.
    ///   - onCompletion: One result (single page) or two (front, back); `CancellationError` when the user cancels.
    public init(image: UIImage? = nil,
                configuration: MBDocCaptureConfiguration = .default,
                onCompletion: @escaping (Result<[ImageScannerResults], Error>) -> Void) {
        self.image = image
        self.configuration = configuration
        self.onCompletion = onCompletion
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    public func makeUIViewController(context: Context) -> ImageScannerController {
        ImageScannerController(image: image, configuration: configuration, delegate: context.coordinator)
    }

    public func updateUIViewController(_ uiViewController: ImageScannerController, context: Context) {
        context.coordinator.onCompletion = onCompletion
    }

    /// Forwards the delegate callbacks to `onCompletion`.
    public final class Coordinator: ImageScannerControllerDelegate {
        var onCompletion: (Result<[ImageScannerResults], Error>) -> Void

        init(onCompletion: @escaping (Result<[ImageScannerResults], Error>) -> Void) {
            self.onCompletion = onCompletion
        }

        public func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults) {
            onCompletion(.success([results]))
        }

        public func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithPage1Results page1Results: ImageScannerResults, andPage2Results page2Results: ImageScannerResults) {
            onCompletion(.success([page1Results, page2Results]))
        }

        public func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
            onCompletion(.failure(CancellationError()))
        }

        public func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
            onCompletion(.failure(error))
        }
    }
}

public extension View {

    /// Presents the scanner full screen and dismisses it when the user is done.
    ///
    /// ```swift
    /// Button("Scan") { isScanning = true }
    ///     .documentScanner(isPresented: $isScanning) { result in
    ///         switch result {
    ///         case .success(let pages): self.pages = pages
    ///         case .failure(is CancellationError): break
    ///         case .failure(let error): self.error = error
    ///         }
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - isPresented: Drives the presentation; set back to `false` automatically on completion.
    ///   - image: An existing image to crop instead of using the camera.
    ///   - configuration: Appearance, behavior, detection and texts.
    ///   - onCompletion: Called after the scanner is dismissed.
    func documentScanner(isPresented: Binding<Bool>,
                         image: UIImage? = nil,
                         configuration: MBDocCaptureConfiguration = .default,
                         onCompletion: @escaping (Result<[ImageScannerResults], Error>) -> Void) -> some View {
        fullScreenCover(isPresented: isPresented) {
            DocumentScanner(image: image, configuration: configuration) { result in
                isPresented.wrappedValue = false
                onCompletion(result)
            }
            .ignoresSafeArea()
            .statusBarHidden()
        }
    }
}
