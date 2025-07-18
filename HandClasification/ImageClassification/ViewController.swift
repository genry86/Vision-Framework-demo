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
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
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

        if cameraPosition == .front {
            return .downMirrored
        } else {
            return .right
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
        
        let request = VNDetectHumanHandPoseRequest(completionHandler: { request, error in
            DispatchQueue.main.async { [weak self] in
                self?.handleResults(request)
            }
        })
        
        let cgOrientation = imageOrientation(for: connection)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: cgOrientation, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - Private

private extension ViewController {
    func handleResults(_ request: VNRequest) {
//        self.classTitle.text = ""
        
        if let results = request.results as? [VNHumanHandPoseObservation] {
            for result in results {
                let thumbTip = try? result.recognizedPoint(.thumbTip)
                let indexTip = try? result.recognizedPoint(.indexTip)
                let middleTip = try? result.recognizedPoint(.middleTip)
                let ringTip = try? result.recognizedPoint(.ringTip)
                let pinkyTip = try? result.recognizedPoint(.littleTip)
                let wrist = try? result.recognizedPoint(.wrist)
                
                if let thumbTip = thumbTip, let indexTip = indexTip, thumbTip.confidence > 0.8, indexTip.confidence > 0.8 {
                    let distance = hypot(thumbTip.x - indexTip.x,
                                         thumbTip.y - indexTip.y)
                    if distance < 0.1 {
                        self.classTitle.text = "👌"
                    }
                }
                
                if let indexTip = indexTip, let middleTip = middleTip, let ringTip = ringTip, let pinkyTip = pinkyTip {
                    let result = indexTip.location.y > middleTip.location.y
                        && ringTip.y < middleTip.y
                        && pinkyTip.y < middleTip.y
                    
                    if result {
                        self.classTitle.text = "✌️"
                    }
                }
                
                if let indexTip = indexTip,
                    let middleTip = middleTip,
                    let ringTip = ringTip,
                    let pinkyTip = pinkyTip,
                    let wrist = wrist {
                    
                    let result = indexTip.y > wrist.y &&
                       pinkyTip.y > wrist.y &&
                       middleTip.y < wrist.y &&
                       ringTip.y < wrist.y
                    
                    if result {
                        self.classTitle.text = "🤘"
                    }
                }
                
                if let indexTip = indexTip,
                    let middleTip = middleTip,
                    let ringTip = ringTip,
                    let pinkyTip = pinkyTip,
                    let thumbTip = thumbTip {
                    
                    let result = thumbTip.x < indexTip.x && // большой отогнут
                        pinkyTip.x > ringTip.x &&  // мизинец отогнут
                        middleTip.y < ringTip.y && // остальные согнуты
                        ringTip.y < pinkyTip.y
                    
                    if result {
                        self.classTitle.text = "🤙"
                    }
                }
                
                if let indexTip = indexTip,
                    let middleTip = middleTip,
                    let ringTip = ringTip,
                    let pinkyTip = pinkyTip,
                    let thumbTip = thumbTip {
                    
                    let result = thumbTip.y > indexTip.y &&
                        indexTip.y < middleTip.y &&
                        ringTip.y < pinkyTip.y
                    
                    if result {
                        self.classTitle.text = "👍"
                    }
                }
                
                if let indexTip = indexTip,
                    let middleTip = middleTip,
                    let ringTip = ringTip,
                    let pinkyTip = pinkyTip,
                    let wrist = wrist,
                    let thumbTip = thumbTip {
                    
                    let palmCenter = wrist.location
                    let result = [thumbTip, indexTip, middleTip, ringTip, pinkyTip].allSatisfy {
                        distance($0.location, palmCenter) < 0.2
                    }
                    
                    if result {
                        self.classTitle.text = "✊"
                    }
                }
            }
        }
    }
    
    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
