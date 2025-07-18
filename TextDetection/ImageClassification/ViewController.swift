//
//  ViewController.swift
//  ImageClassification
//
//  Created by Genry on 14.04.2025.
//

import AVFoundation
import Vision
import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var classTitle: UILabel!
    @IBOutlet weak var cameraLayerView: UIView!
    
    let queue = DispatchQueue(label: "camera.frame.classification")
    lazy var session: AVCaptureSession = {
        let object = AVCaptureSession()
        object.sessionPreset = .photo
        return object
    }()
    lazy var config: MLModelConfiguration = {
        let object = MLModelConfiguration()
        object.computeUnits = .all
        return object
    }()
    
    let videoOutput = AVCaptureVideoDataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
}

// MARK: - Private Setup

private extension ViewController {
    func setupCamera() {
        // 1. Choose a camera
        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: camera)
        else {
            return
        }
        
        // 2. Add input to session
        session.addInput(input)
     
        // 3. Setup output for video data (for processing)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(videoOutput)
 
        // 4. Create and add preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        cameraLayerView.layer.addSublayer(previewLayer)
        
        // 5. Start running the session
        queue.async { [weak self] in
            guard let self = self else { return }
            self.session.startRunning()
        }
    }
    
    func imageOrientation(for connection: AVCaptureConnection) -> CGImagePropertyOrientation {
        guard let inputPort = connection.inputPorts.first,
              let deviceInput = inputPort.input as? AVCaptureDeviceInput else {
            return .right
        }

        let cameraPosition = deviceInput.device.position

        // Поскольку CVPixelBuffer из фронталки всегда зеркальный и "вниз"
        if cameraPosition == .front {
            return .downMirrored
        } else {
            return .right // для задней камеры в портретном режиме
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let detectBarcodesRequest = VNRecognizeTextRequest(completionHandler: { request, error in
            DispatchQueue.main.async { [weak self] in
                self?.handleResult(request)
            }
        })
        
        let cgOrientation = imageOrientation(for: connection)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: cgOrientation, options: [:])
        try? handler.perform([detectBarcodesRequest])
    }
}

// MARK: - Private

private extension ViewController {
    func handleResult(_ request: VNRequest) {
        if let results = request.results as? [VNRecognizedTextObservation] {
            for result in results {
                guard let сandidate = result.topCandidates(1).first else {
                    continue
                }
                self.classTitle.text = "|\(сandidate.confidence)| " + сandidate.string
            }
        }
    }
}
