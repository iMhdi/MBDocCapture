//
//  CaptureSession.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019 El Mahdi Boukhris <m.boukhris@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

import UIKit
import AVFoundation

/// A class containing global variables and settings for this capture session
final class CaptureSession {
    
    static let current = CaptureSession()
    
    /// The AVCaptureDevice used for the flash and focus setting
    var device: CaptureDevice?
    
    /// Whether the user is past the scanning screen or not (needed to disable auto scan on other screens)
    var isEditing: Bool
    
    /// The status of auto scan. Auto scan tries to automatically scan a detected rectangle if it has a high enough accuracy.
    var isAutoScanEnabled: Bool
    
    /// The orientation of the captured image
    var editImageOrientation: CGImagePropertyOrientation
    
    /// The type of document to scan
    var isScanningTwoFacedDocument: Bool
    
    /// Property for storing results in case of 2 faced documents
    var firstScanResult: ImageScannerResults?
    
    /// Resets the per-scan state when a new scanner is created.
    func reset(with configuration: MBDocCaptureConfiguration) {
        isEditing = false
        isAutoScanEnabled = configuration.behavior.isAutoScanEnabled
        isScanningTwoFacedDocument = configuration.behavior.scanMode == .twoSided
        firstScanResult = nil
        editImageOrientation = .up
    }

    /// Whether the device has a torch that can be toggled.
    var isTorchAvailable: Bool { device?.isTorchAvailable ?? false }

    /// Turns the torch on or off. Returns the new state.
    @discardableResult
    func setTorch(on: Bool) -> Bool {
        guard let device = device, device.isTorchAvailable, (try? device.lockForConfiguration()) != nil else { return false }
        defer { device.unlockForConfiguration() }
        device.torchMode = on ? .on : .off
        return on
    }

    private init(isAutoScanEnabled: Bool = true, editImageOrientation: CGImagePropertyOrientation = .up) {
        self.device = AVCaptureDevice.default(for: .video)
        
        self.isScanningTwoFacedDocument = false
        self.isEditing = false
        self.isAutoScanEnabled = isAutoScanEnabled
        self.editImageOrientation = editImageOrientation
    }
}
