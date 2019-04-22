//
//  ViewController.swift
//  MBDocCapture
//
//  Created by El Mahdi Boukhris on 16/04/2019.
//  Copyright © 2019 El Mahdi Boukhris <m.boukhris@gmail.com>
//

import UIKit
import MBDocCapture

class ViewController: UIViewController {

    @IBOutlet weak var resultContainerView: UIView!
    @IBOutlet weak var page1Preview: UIImageView!
    @IBOutlet weak var page2Preview: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func didSelectType1Button(_ sender: Any) {
        let scanner = ImageScannerController(delegate: self)
        scanner.shouldScanTwoFaces = false
        present(scanner, animated: true)
    }
    
    @IBAction func didSelectType2Button(_ sender: Any) {
        let scanner = ImageScannerController(delegate: self)
        scanner.shouldScanTwoFaces = true
        present(scanner, animated: true)
    }
    
    @IBAction func didSelectPreview1Button(_ sender: Any) {
        let scanner = ImageScannerController(image: page1Preview.image, delegate: self)
        present(scanner, animated: true)
    }
    
    @IBAction func didSelectPreview2Button(_ sender: Any) {
        let scanner = ImageScannerController(image: page2Preview.image, delegate: self)
        present(scanner, animated: true)
    }
}

extension ViewController: ImageScannerControllerDelegate {
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults) {
        scanner.dismiss(animated: true) {
            self.resultContainerView.isHidden    =   false
            self.page2Preview.isHidden           =   true
            
            if results.doesUserPreferEnhancedImage {
                self.page1Preview.image          =   results.enhancedImage
            } else {
                self.page1Preview.image          =   results.scannedImage
            }
        }
    }
    
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithPage1Results page1Results: ImageScannerResults, andPage2Results page2Results: ImageScannerResults) {
        scanner.dismiss(animated: true) {
            self.resultContainerView.isHidden    =   false
            self.page2Preview.isHidden           =   false
            
            if page1Results.doesUserPreferEnhancedImage {
                self.page1Preview.image          =   page1Results.enhancedImage
            } else {
                self.page1Preview.image          =   page1Results.scannedImage
            }
            
            if page2Results.doesUserPreferEnhancedImage {
                self.page2Preview.image          =   page2Results.enhancedImage
            } else {
                self.page2Preview.image          =   page2Results.scannedImage
            }
        }
    }
    
    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        scanner.dismiss(animated: true)
    }
    
    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
        scanner.dismiss(animated: true)
    }
}
