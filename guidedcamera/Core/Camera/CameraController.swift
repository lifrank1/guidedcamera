//
//  CameraController.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import AVFoundation
import UIKit

/// Wraps AVFoundation camera session
class CameraController: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var error: CameraError?
    
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureMovieFileOutput()
    private var videoFileURL: URL?
    
    // Preview layer is now managed by CameraPreviewUIView
    // This property is kept for compatibility but preview should be accessed via the view
    var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
    
    var captureSession: AVCaptureSession {
        return session
    }
    
    override init() {
        super.init()
        checkPermissionsAndSetup()
    }
    
    private func checkPermissionsAndSetup() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.error = .setupFailed
                    }
                }
            }
        default:
            error = .setupFailed
        }
    }
    
    private func setupSession() {
        print("📷 [CameraController] Setting up camera session...")
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Remove existing inputs
        for input in session.inputs {
            session.removeInput(input)
        }
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ [CameraController] No video device found")
            error = .setupFailed
            session.commitConfiguration()
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                print("✅ [CameraController] Video input added")
            } else {
                print("❌ [CameraController] Cannot add video input")
                error = .setupFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("❌ [CameraController] Failed to create video input: \(error)")
            self.error = .setupFailed
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            print("✅ [CameraController] Photo output added")
        } else {
            print("⚠️ [CameraController] Cannot add photo output")
        }
        
        // Add video output
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            print("✅ [CameraController] Video output added")
        } else {
            print("⚠️ [CameraController] Cannot add video output")
        }
        
        session.commitConfiguration()
        print("✅ [CameraController] Session configuration complete")
    }
    
    func startSession() {
        guard !isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        guard isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
    
    func capturePhoto(completion: @escaping (Result<UIImage, CameraError>) -> Void) {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate(completion: completion))
    }
    
    func startVideoRecording() throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        videoFileURL = tempURL
        
        if videoOutput.isRecording {
            videoOutput.stopRecording()
        }
        
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        return tempURL
    }
    
    func stopVideoRecording() {
        videoOutput.stopRecording()
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Video recording finished
    }
}

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, CameraError>) -> Void
    
    init(completion: @escaping (Result<UIImage, CameraError>) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(.failure(.captureFailed(error)))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(.failure(.imageProcessingFailed))
            return
        }
        
        completion(.success(image))
    }
}

enum CameraError: LocalizedError {
    case setupFailed
    case captureFailed(Error)
    case imageProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .setupFailed:
            return "Failed to set up camera"
        case .captureFailed(let error):
            return "Capture failed: \(error.localizedDescription)"
        case .imageProcessingFailed:
            return "Failed to process captured image"
        }
    }
}

