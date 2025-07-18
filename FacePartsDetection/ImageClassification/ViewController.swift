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
    
    private var landmarkLayer = CAShapeLayer()
    private var landmarkLabels: [UILabel] = []
    
    private let faceLayer = CAShapeLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupLandmarks()
        setupFaceLayer()
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
    
    func setupLandmarks() {
        landmarkLayer.frame = view.bounds
        landmarkLayer.strokeColor = UIColor.red.cgColor
        landmarkLayer.fillColor = UIColor.clear.cgColor
        landmarkLayer.lineWidth = 2
        previewLayer.addSublayer(landmarkLayer)
    }
    
    func setupFaceLayer() {
        faceLayer.frame = view.bounds
        faceLayer.strokeColor = UIColor.blue.cgColor
        faceLayer.lineWidth = 2
        faceLayer.fillColor = UIColor.clear.cgColor
        previewLayer.addSublayer(faceLayer)
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
        
        let detectFaceLandmarksRequest = VNDetectFaceLandmarksRequest { request, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.handleLandmarksDetectionRequest(request)
            }
        }
        
        let detectFaceRectanglesRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.handleFaceDetectionRequest(request)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: connection.orientation, options: [:])
        try? handler.perform([detectFaceRectanglesRequest, detectFaceLandmarksRequest])
    }
}

// MARK: - Private

private extension ViewController {
    func handleFaceDetectionRequest(_ request: VNRequest) {
        self.faceLayer.path = nil
        guard let observations = request.results as? [VNFaceObservation] else {
            return
        }
        drawFaceBoxes(observations)
    }
    
    func drawFaceBoxes(_ faces: [VNFaceObservation]) {
        let path = UIBezierPath()

        for face in faces {
            let box = face.boundingBox.invertRect
            let convertedRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: box)
            path.append(UIBezierPath(rect: convertedRect))
        }

        faceLayer.path = path.cgPath
    }
    
    func handleLandmarksDetectionRequest(_ request: VNRequest) {
        self.classTitle.text = ""
        guard let results = request.results as? [VNFaceObservation] else { return }
        
        for face in results {
            self.cleanFaceObjects()
            guard let landmarks = face.landmarks else { continue }
            let box = face.boundingBox
            
            if let landmark = landmarks.faceContour {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points)
            }
            
            if let landmark = landmarks.medianLine {
                let points = landmark.normalizedPoints.inBox(box).switchedXY        // (x,y) - Y[1-0]-X[0-1] for Layer convertion
                let correctPoints = landmark.normalizedPoints.inBox(box).invertedY  // (x,y) - X[0-1]-Y[0-1] - for math
                self.drawLandmarks(points, color: .link)
            }
            
            if let mouth = landmarks.outerLips {
                let points = mouth.normalizedPoints.inBox(box).switchedXY
                let correctPoints = points.switchedXY.invertedY
                
                if points.count >= 5 {
                    let left = correctPoints.mostLeftPoint()
                    let right = correctPoints.mostRightPoint()
                    let center = correctPoints.centerPoint()
                    
                    let leftDiff = left.y - center.y
                    let rightDiff = right.y - center.y
                    
                    let isSmiling = leftDiff > 0.0 && rightDiff > 0.0
                    
                    self.classTitle.text = isSmiling ? "😄 Smiling" : "😐 Not Smiling"
                    self.drawLandmarks(points, color: .cyan)
                }
            }
            if let landmark = landmarks.innerLips {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .systemPink)
            }
            
            if let landmark = landmarks.nose {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .brown)
            }
            
            if let landmark = landmarks.noseCrest {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .green)
            }
             
            if let landmark = landmarks.leftEye {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .magenta)
            }
            if let landmark = landmarks.rightEye {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .magenta)
            }
            
            if let landmark = landmarks.leftEyebrow {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .orange)
            }
            if let landmark = landmarks.rightEyebrow {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .orange)
            }
            
            if let landmark = landmarks.leftPupil {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .white)
            }
            if let landmark = landmarks.rightPupil {
                let points = landmark.normalizedPoints.inBox(box).switchedXY
                self.drawLandmarks(points, color: .white)
            }
        }
    }
    
    func cleanFaceObjects() {
        self.landmarkLayer.sublayers?.forEach { $0.removeFromSuperlayer() } // очищаем предыдущие
        self.landmarkLabels.forEach { $0.removeFromSuperview() }
        self.landmarkLabels.removeAll()
    }
    
    private func drawLandmarks(_ points: [CGPoint], color: UIColor = UIColor.red) {
        DispatchQueue.main.async {
            for (index, point) in points.enumerated() {
                let converted = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: point)

                let circle = UIBezierPath(arcCenter: converted, radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: true)

                let dotLayer = CAShapeLayer()
                dotLayer.path = circle.cgPath
                dotLayer.fillColor = color.cgColor
                self.landmarkLayer.addSublayer(dotLayer)
                
                let label = UILabel(frame: CGRect(x: converted.x + 4, y: converted.y - 8, width: 20, height: 15))
                label.text = "\(index)"
                label.font = UIFont.systemFont(ofSize: 10)
                label.textColor = .yellow
                self.view.addSubview(label)
                self.landmarkLabels.append(label)
            }
        }
    }
}
