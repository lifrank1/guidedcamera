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
    // Retain photo capture delegates to prevent deallocation
    private var activePhotoDelegates: [PhotoCaptureDelegate] = []
    
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
        print("📸 [CameraController] capturePhoto called")
        print("📸 [CameraController] Session running: \(isSessionRunning)")
        print("📸 [CameraController] Photo output connections: \(photoOutput.connections.count)")
        
        guard isSessionRunning else {
            print("❌ [CameraController] Session not running, cannot capture")
            completion(.failure(.setupFailed))
            return
        }
        
        guard !photoOutput.connections.isEmpty else {
            print("❌ [CameraController] Photo output has no connections")
            completion(.failure(.setupFailed))
            return
        }
        
        let settings = AVCapturePhotoSettings()
        print("📸 [CameraController] Creating photo settings and starting capture...")
        let delegate = PhotoCaptureDelegate(completion: completion)
        // Retain delegate to prevent deallocation before capture completes
        activePhotoDelegates.append(delegate)
        photoOutput.capturePhoto(with: settings, delegate: delegate)
        print("📸 [CameraController] capturePhoto request sent to output")
        
        // Clean up delegate after a delay (delegate will be retained by photoOutput during capture)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.activePhotoDelegates.removeAll { $0 === delegate }
        }
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

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, CameraError>) -> Void
    
    init(completion: @escaping (Result<UIImage, CameraError>) -> Void) {
        self.completion = completion
        print("📸 [PhotoCaptureDelegate] Delegate created")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📸 [PhotoCaptureDelegate] didFinishProcessingPhoto called")
        
        if let error = error {
            print("❌ [PhotoCaptureDelegate] Error processing photo: \(error)")
            completion(.failure(.captureFailed(error)))
            return
        }
        
        print("📸 [PhotoCaptureDelegate] Getting image data...")
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ [PhotoCaptureDelegate] No image data in photo")
            completion(.failure(.imageProcessingFailed))
            return
        }
        
        print("📸 [PhotoCaptureDelegate] Image data size: \(imageData.count) bytes")
        guard let image = UIImage(data: imageData) else {
            print("❌ [PhotoCaptureDelegate] Failed to create UIImage from data")
            completion(.failure(.imageProcessingFailed))
            return
        }
        
        print("✅ [PhotoCaptureDelegate] Image created successfully, size: \(image.size)")
        completion(.success(image))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor settings: AVCapturePhotoSettings) {
        print("📸 [PhotoCaptureDelegate] willCapturePhotoFor called")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor settings: AVCapturePhotoSettings) {
        print("📸 [PhotoCaptureDelegate] didCapturePhotoFor called")
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

