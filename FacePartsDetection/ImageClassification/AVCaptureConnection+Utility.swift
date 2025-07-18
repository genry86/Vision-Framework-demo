//
//  AVCaptureConnection+Utility.swift
//  ImageClassification
//
//  Created by Genry on 08.05.2025.
//

import AVFoundation
import CoreImage
import Vision
import UIKit

extension AVCaptureConnection {
    var orientation: CGImagePropertyOrientation {
        let connection = self
        guard
            let inputPort = connection.inputPorts.first,
            let deviceInput = inputPort.input as? AVCaptureDeviceInput
        else {
            return .right
        }

        let cameraPosition = deviceInput.device.position

        if cameraPosition == .front {
            return .left
        } else {
            return .right
        }
    }
}
