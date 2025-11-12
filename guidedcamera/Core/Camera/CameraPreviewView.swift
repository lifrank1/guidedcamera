//
//  CameraPreviewView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI
import AVFoundation

/// SwiftUI view for camera preview
struct CameraPreviewView: UIViewRepresentable {
    let cameraController: CameraController
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.setupPreviewLayer(with: cameraController)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updateFrame()
    }
}

/// UIView wrapper for AVCaptureVideoPreviewLayer
class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var cameraController: CameraController?
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    func setupPreviewLayer(with controller: CameraController) {
        cameraController = controller
        videoPreviewLayer.session = controller.captureSession
        videoPreviewLayer.videoGravity = .resizeAspectFill
        
        // Ensure frame is set after layout
        DispatchQueue.main.async { [weak self] in
            self?.updateFrame()
        }
    }
    
    func updateFrame() {
        videoPreviewLayer.frame = bounds
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateFrame()
    }
}

