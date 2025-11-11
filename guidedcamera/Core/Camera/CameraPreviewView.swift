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
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = cameraController.previewLayer
        
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

