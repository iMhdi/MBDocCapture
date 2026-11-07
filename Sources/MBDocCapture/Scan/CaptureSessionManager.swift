//
//  CaptureSessionManager.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019-2026 El Mahdi Boukhris <m.boukhris@gmail.com>. MIT License.
//

import UIKit
import CoreImage
import UIKit
import AVFoundation

/// A set of functions that inform the delegate object of the state of the detection.
protocol RectangleDetectionDelegateProtocol: AnyObject {

    /// Called when the capture of a picture has started.
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager)

    /// Called when a rectangle has been detected (or lost, with `nil`), in the coordinates of an image of `imageSize`.
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectRect rect: Rectangle?, _ imageSize: CGSize)

    /// Called when a picture with or without a rectangle has been captured.
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withRect rect: Rectangle?)

    /// Called when an error occured with the capture session manager.
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error)
}

/// Sets up and manages the `AVCaptureSession`, live rectangle detection and photo capture.
final class CaptureSessionManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let videoPreviewLayer: AVCaptureVideoPreviewLayer
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "mbdoccapture.session")
    private let rectangleFunnel: RectangleFeaturesFunnel
    weak var delegate: RectangleDetectionDelegateProtocol?
    private var displayedRectangleResult: RectangleDetectorResult?
    private let photoOutput = AVCapturePhotoOutput()

    /// Whether the CaptureSessionManager should be detecting rectangles.
    private var isDetecting = true

    /// The number of times no rectangles have been found in a row.
    private var noRectangleCount = 0

    /// The minimum number of time required by `noRectangleCount` to validate that no rectangles have been found.
    private let noRectangleThreshold = 3

    // MARK: Life Cycle

    /// Returns `nil` when no camera is available (e.g. the Simulator).
    init?(videoPreviewLayer: AVCaptureVideoPreviewLayer, detection: MBDocCaptureConfiguration.Detection) {
        self.videoPreviewLayer = videoPreviewLayer
        self.rectangleFunnel = RectangleFeaturesFunnel(detection: detection)
        super.init()

        guard let device = AVCaptureDevice.default(for: .video),
              let deviceInput = try? AVCaptureDeviceInput(device: device) else {
            return nil
        }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .photo

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true

        guard captureSession.canAddInput(deviceInput),
              captureSession.canAddOutput(photoOutput),
              captureSession.canAddOutput(videoOutput) else {
            return nil
        }

        if (try? device.lockForConfiguration()) != nil {
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        }

        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)

        if #available(iOS 16.0, *) {
            if let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                photoOutput.maxPhotoDimensions = largest
            }
        } else {
            photoOutput.isHighResolutionCaptureEnabled = true
        }

        videoPreviewLayer.session = captureSession
        videoPreviewLayer.videoGravity = .resizeAspectFill

        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "mbdoccapture.video_output"))
    }

    // MARK: Capture Session Life Cycle

    /// Starts the camera and detecting rectangles, asking for camera permission if needed.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isDetecting = true
            sessionQueue.async { [captureSession] in
                if !captureSession.isRunning { captureSession.startRunning() }
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async { self?.start() }
            }
        default:
            delegate?.captureSessionManager(self, didFailWithError: ImageScannerControllerError.authorization)
        }
    }

    func stop() {
        sessionQueue.async { [captureSession] in captureSession.stopRunning() }
    }

    func capturePhoto() {
        guard let connection = photoOutput.connection(with: .video), connection.isEnabled, connection.isActive else {
            delegate?.captureSessionManager(self, didFailWithError: ImageScannerControllerError.capture)
            return
        }

        let photoSettings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *) {
            photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            photoSettings.isHighResolutionPhotoEnabled = true
        }
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isDetecting, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let rectangle = CIRectangleDetector.rectangle(forImage: CIImage(cvPixelBuffer: pixelBuffer))
        processRectangle(rectangle: rectangle, imageSize: imageSize)
    }

    private func processRectangle(rectangle: Rectangle?, imageSize: CGSize) {
        guard let rectangle = rectangle else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.noRectangleCount += 1
                if self.noRectangleCount > self.noRectangleThreshold {
                    // Restart the auto scan threshold the next time a rectangle is found.
                    self.rectangleFunnel.currentAutoScanPassCount = 0
                    self.displayedRectangleResult = nil
                    self.delegate?.captureSessionManager(self, didDetectRect: nil, imageSize)
                }
            }
            return
        }

        noRectangleCount = 0
        rectangleFunnel.add(rectangle, currentlyDisplayedRectangle: displayedRectangleResult?.rectangle) { result, rectangle in
            displayRectangleResult(rectangleResult: RectangleDetectorResult(rectangle: rectangle, imageSize: imageSize))
            if result == .showAndAutoScan, CaptureSession.current.isAutoScanEnabled, !CaptureSession.current.isEditing {
                capturePhoto()
            }
        }
    }

    @discardableResult private func displayRectangleResult(rectangleResult: RectangleDetectorResult) -> Rectangle {
        displayedRectangleResult = rectangleResult
        let rect = rectangleResult.rectangle.toCartesian(withHeight: rectangleResult.imageSize.height)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.captureSessionManager(self, didDetectRect: rect, rectangleResult.imageSize)
        }
        return rect
    }
}

extension CaptureSessionManager: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            delegate?.captureSessionManager(self, didFailWithError: error)
            return
        }

        CaptureSession.current.setImageOrientation()
        isDetecting = false
        rectangleFunnel.currentAutoScanPassCount = 0
        delegate?.didStartCapturingPicture(for: self)

        guard let imageData = photo.fileDataRepresentation() else {
            delegate?.captureSessionManager(self, didFailWithError: ImageScannerControllerError.capture)
            return
        }
        completeImageCapture(with: imageData)
    }

    /// Decodes the photo off the main thread, maps the displayed rectangle onto it and hands both to the delegate.
    private func completeImageCapture(with imageData: Data) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            CaptureSession.current.isEditing = true
            guard let image = UIImage(data: imageData) else {
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.delegate?.captureSessionManager(self, didFailWithError: ImageScannerControllerError.capture)
                }
                return
            }

            var angle: CGFloat = 0.0
            switch image.imageOrientation {
            case .right: angle = CGFloat.pi / 2
            case .up: angle = CGFloat.pi
            default: break
            }

            var rect: Rectangle?
            if let displayedRectangleResult = self?.displayedRectangleResult {
                rect = self?.displayRectangleResult(rectangleResult: displayedRectangleResult)
                rect = rect?.scale(displayedRectangleResult.imageSize, image.size, withRotationAngle: angle)
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.delegate?.captureSessionManager(self, didCapturePicture: image, withRect: rect)
            }
        }
    }
}

/// Data structure representing the result of the detection of a rectangle.
private struct RectangleDetectorResult {
    /// The detected rectangle.
    let rectangle: Rectangle
    /// The size of the image the rectangle was detected on.
    let imageSize: CGSize
}
