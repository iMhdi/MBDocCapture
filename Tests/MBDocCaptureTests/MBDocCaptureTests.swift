import XCTest
@testable import MBDocCapture

final class MBDocCaptureTests: XCTestCase {

    func testReorganizeSortsCornersClockwiseFromTopLeft() {
        var rect = Rectangle(topLeft: CGPoint(x: 100, y: 100), topRight: CGPoint(x: 0, y: 0),
                             bottomRight: CGPoint(x: 0, y: 100), bottomLeft: CGPoint(x: 100, y: 0))
        rect.reorganize()
        XCTAssertEqual(rect, Rectangle(rect: CGRect(x: 0, y: 0, width: 100, height: 100)))
    }

    func testFunnelAutoScansOnlyAfterConfiguredStableFrames() {
        var detection = MBDocCaptureConfiguration.Detection()
        detection.autoScanStabilityFrames = 5
        let funnel = RectangleFeaturesFunnel(detection: detection)
        let rect = Rectangle(rect: CGRect(x: 10, y: 10, width: 200, height: 300))

        var displayed: Rectangle?
        var autoScanFrame: Int?
        for frame in 1...20 where autoScanFrame == nil {
            funnel.add(rect, currentlyDisplayedRectangle: displayed) { result, rectangle in
                displayed = rectangle
                if result == .showAndAutoScan { autoScanFrame = frame }
            }
        }
        // 3 frames to fill the funnel, 1 to display, then more than 5 stable frames.
        XCTAssertEqual(autoScanFrame, 9)
    }

    func testProcessorCropsToRectangleAndEnhances() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600), format: {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; return format
        }()).image { context in
            UIColor.darkGray.setFill(); context.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
            UIColor.white.setFill(); context.fill(CGRect(x: 50, y: 100, width: 300, height: 400))
        }

        var configuration = MBDocCaptureConfiguration()
        configuration.behavior.prefersEnhancedImageByDefault = true
        let results = try XCTUnwrap(ImageProcessor.process(image: image, rect: Rectangle(rect: CGRect(x: 50, y: 100, width: 300, height: 400)), configuration: configuration))

        XCTAssertEqual(results.scannedImage.size.width, 300, accuracy: 2)
        XCTAssertEqual(results.scannedImage.size.height, 400, accuracy: 2)
        XCTAssertNotNil(results.enhancedImage)
        XCTAssertTrue(results.doesUserPreferEnhancedImage)
        XCTAssertTrue(results.preferredImage === results.enhancedImage)

        configuration.behavior.isEnhancementAvailable = false
        let plain = try XCTUnwrap(ImageProcessor.process(image: image, rect: Rectangle(rect: CGRect(x: 0, y: 0, width: 400, height: 600)), configuration: configuration))
        XCTAssertNil(plain.enhancedImage)
        XCTAssertFalse(plain.doesUserPreferEnhancedImage)
    }

    func testNormalizedImageIsUpAndScaleOne() {
        let base = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 20)).image { _ in }
        let rotated = UIImage(cgImage: base.cgImage!, scale: 2, orientation: .right)
        let normalized = rotated.normalized()
        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertEqual(normalized.scale, 1)
        XCTAssertEqual(normalized.size, CGSize(width: rotated.size.width * 2, height: rotated.size.height * 2))
    }

    func testDefaultStringsAreResolvedFromBundle() {
        let strings = MBDocCaptureConfiguration.Strings()
        XCTAssertFalse(strings.cancel.hasPrefix("mbdoccapture."))
        XCTAssertFalse(strings.hintHoldStill.isEmpty)
    }
}
