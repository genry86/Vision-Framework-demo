//
//  UIImage+Utility.swift
//  ImageClassification
//
//  Created by Genry on 08.05.2025.
//

import UIKit

extension UIImage {
    func hasFace() -> Bool {
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        guard let personciImage = CIImage(image: self),
              let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy) else {
            return false
        }
        let faces = faceDetector.features(in: personciImage)
        return !faces.isEmpty
    }
}
