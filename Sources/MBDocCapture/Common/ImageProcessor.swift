//
//  ImageProcessor.swift
//  MBDocCapture
//
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit
import CoreImage

/// Crops, deskews and enhances an image.
enum ImageProcessor {

    /// - Parameters:
    ///   - image: An `.up`-oriented image with a scale of 1.
    ///   - rect: The document corners, in `image` coordinates (origin top left).
    static func process(image: UIImage, rect: Rectangle, configuration: MBDocCaptureConfiguration) -> ImageScannerResults? {
        guard let ciImage = CIImage(image: image) else { return nil }

        var cartesianRect = rect.toCartesian(withHeight: image.size.height)
        cartesianRect.reorganize()

        let filteredImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesianRect.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesianRect.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesianRect.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesianRect.topRight)
        ])

        guard let cgImage = CIContext.shared.createCGImage(filteredImage, from: filteredImage.extent) else { return nil }
        let scannedImage = UIImage(cgImage: cgImage).withFixedOrientation()

        let enhancedImage = configuration.behavior.isEnhancementAvailable
            ? filteredImage.applyingAdaptiveThreshold(range: configuration.detection.enhancementRange)?.withFixedOrientation()
            : nil

        return ImageScannerResults(originalImage: image,
                                   scannedImage: scannedImage,
                                   enhancedImage: enhancedImage,
                                   doesUserPreferEnhancedImage: configuration.behavior.prefersEnhancedImageByDefault && enhancedImage != nil,
                                   detectedRectangle: rect)
    }
}
