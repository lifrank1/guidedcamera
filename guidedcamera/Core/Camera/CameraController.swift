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
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var videoFileURL: URL?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentVideoDevice: AVCaptureDevice?
    
    // Retain photo capture delegates to prevent deallocation
    private var activePhotoDelegates: [PhotoCaptureDelegate] = []
    
    // Real-time detection support
    weak var videoDataDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    private var frameCount = 0
    private let frameSkipInterval = 10 // Process every 10th frame (~3 FPS on 30 FPS camera)
    
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
    
    /// Enable/disable real-time detection
    func setRealTimeDetectionEnabled(_ enabled: Bool) {
        videoDataOutput.setSampleBufferDelegate(enabled ? self : nil, queue: enabled ? DispatchQueue.global(qos: .userInitiated) : nil)
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
        
        // Add video input with current position
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            print("❌ [CameraController] No video device found")
            error = .setupFailed
            session.commitConfiguration()
            return
        }
        
        currentVideoDevice = videoDevice
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                currentVideoInput = videoInput
                print("✅ [CameraController] Video input added (position: \(cameraPosition == .back ? "back" : "front"))")
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
        
        // Add video data output for real-time detection
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            print("✅ [CameraController] Video data output added for real-time detection")
        } else {
            print("⚠️ [CameraController] Cannot add video data output")
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
        // Configure flash mode
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
            print("📸 [CameraController] Flash mode set to: \(flashMode == .on ? "on" : flashMode == .auto ? "auto" : "off")")
        }
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
    
    /// Switch between front and back camera
    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = cameraPosition == .back ? .front : .back
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            print("❌ [CameraController] Cannot find camera at position: \(newPosition == .back ? "back" : "front")")
            return
        }
        
        session.beginConfiguration()
        
        // Remove current input
        if let currentInput = currentVideoInput {
            session.removeInput(currentInput)
        }
        
        // Add new input
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentVideoInput = newInput
                currentVideoDevice = newDevice
                cameraPosition = newPosition
                print("✅ [CameraController] Switched to \(newPosition == .back ? "back" : "front") camera")
            } else {
                print("❌ [CameraController] Cannot add new video input")
                // Try to restore old input
                if let oldInput = currentVideoInput {
                    session.addInput(oldInput)
                }
            }
        } catch {
            print("❌ [CameraController] Failed to create new video input: \(error)")
            // Try to restore old input
            if let oldInput = currentVideoInput {
                session.addInput(oldInput)
            }
        }
        
        session.commitConfiguration()
    }
    
    /// Toggle flash mode: off -> auto -> on -> off
    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .auto
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
        print("📸 [CameraController] Flash mode toggled to: \(flashMode == .on ? "on" : flashMode == .auto ? "auto" : "off")")
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

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process every Nth frame for performance
        frameCount += 1
        guard frameCount % frameSkipInterval == 0 else { return }
        
        // Forward to delegate if set
        videoDataDelegate?.captureOutput?(output, didOutput: sampleBuffer, from: connection)
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

