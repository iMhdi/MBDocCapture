//
//  CIImage+Utils.swift
//  MBDocCapture
//
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

extension CIImage {

    /// Grayscale "scanned paper" look: luminance below `range.lowerBound` turns black, above `range.upperBound` turns white,
    /// with a smooth ramp in between (same curve as the former CIKernel smoothstep, without the deprecated Core Image Kernel Language).
    func applyingAdaptiveThreshold(range: ClosedRange<CGFloat> = 0.25...0.75) -> UIImage? {
        let mono = CIFilter.colorControls()
        mono.inputImage = self
        mono.saturation = 0

        let lower = range.lowerBound, upper = range.upperBound
        let curve = CIFilter.toneCurve()
        curve.inputImage = mono.outputImage
        curve.point0 = CGPoint(x: 0, y: 0)
        curve.point1 = CGPoint(x: lower, y: 0)
        curve.point2 = CGPoint(x: (lower + upper) / 2, y: 0.5)
        curve.point3 = CGPoint(x: upper, y: 1)
        curve.point4 = CGPoint(x: 1, y: 1)

        guard let output = curve.outputImage,
              let cgImage = CIContext.shared.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension CIContext {
    /// Creating a CIContext is expensive: reuse one.
    static let shared = CIContext(options: nil)
}
