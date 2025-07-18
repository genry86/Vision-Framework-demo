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
    
    private var boxLayers = [CAShapeLayer]()
    
    let semaphore = DispatchSemaphore(value: 1)
    
    var inputImageSize: CGSize = CGSizeZero
    
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
        
        inputImageSize = view.bounds.size
        
        // 5. Start running the session
        queue.async { [weak self] in
            guard let self = self else { return }
            self.session.startRunning()
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
        guard semaphore.wait(timeout: .now()) == .success else { return }
        
        guard
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else {
            return
        }
        
        let detectHumanRectanglesRequest = VNDetectHumanRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNHumanObservation] else {
                self?.semaphore.signal()
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.drawBoundingBoxes(results)
                self?.semaphore.signal()
            }
        }
 
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .downMirrored, options: [:])
        try? handler.perform([detectHumanRectanglesRequest])
    }
}

// MARK: - Private

private extension ViewController {
    func drawBoundingBoxes(_ humans: [VNHumanObservation]) {
        for layer in boxLayers {
            layer.removeFromSuperlayer()
        }
        boxLayers.removeAll()
         
        for human in humans {
            let boundingBox = human.boundingBox
            let convertedRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: boundingBox)
            
            let boxPath = UIBezierPath(rect: convertedRect)
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = boxPath.cgPath
            shapeLayer.strokeColor = UIColor.red.cgColor
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineWidth = 2.0

            self.previewLayer.addSublayer(shapeLayer)
            boxLayers.append(shapeLayer)
        }
    }
}
