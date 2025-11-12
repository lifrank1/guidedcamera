//
//  CaptureManager.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import UIKit
import CoreLocation

/// Handles photo/video capture with metadata
class CaptureManager: ObservableObject {
    static let shared = CaptureManager()
    
    private let cameraController: CameraController
    private let mediaStore = MediaStore.shared
    private let locationManager = CLLocationManager()
    
    private init() {
        self.cameraController = CameraController()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    /// Capture a photo
    func capturePhoto(sessionId: String, stepId: String, completion: @escaping (Result<CapturedMedia, Error>) -> Void) {
        print("📸 [CaptureManager] capturePhoto called for step: \(stepId)")
        print("📸 [CaptureManager] Camera session running: \(cameraController.isSessionRunning)")
        
        cameraController.capturePhoto { [weak self] result in
            guard let self = self else {
                print("❌ [CaptureManager] Self is nil in capture completion")
                return
            }
            
            print("📸 [CaptureManager] Camera capture result received")
            
            switch result {
            case .success(let image):
                print("✅ [CaptureManager] Image captured, size: \(image.size)")
                do {
                    let fileURL = try self.mediaStore.savePhoto(image, for: sessionId, stepId: stepId)
                    print("✅ [CaptureManager] Image saved to: \(fileURL.path)")
                    
                    var metadata = MediaMetadata()
                    metadata.deviceInfo = UIDevice.current.model
                    
                    // Add location if available
                    if let location = self.locationManager.location {
                        metadata.location = LocationData(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            timestamp: location.timestamp
                        )
                    }
                    
                    let media = CapturedMedia(
                        stepId: stepId,
                        type: .photo,
                        fileURL: fileURL,
                        metadata: metadata
                    )
                    
                    print("✅ [CaptureManager] Calling completion with success")
                    completion(.success(media))
                } catch {
                    print("❌ [CaptureManager] Failed to save image: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                print("❌ [CaptureManager] Camera capture failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Start video recording
    func startVideoRecording() throws -> URL {
        return try cameraController.startVideoRecording()
    }
    
    /// Stop video recording
    func stopVideoRecording(sessionId: String, stepId: String, completion: @escaping (Result<CapturedMedia, Error>) -> Void) {
        cameraController.stopVideoRecording()
        
        // Note: In a real implementation, we'd wait for the delegate callback
        // For now, we'll handle this in the camera controller's delegate
        // This is a simplified version
    }
    
    var camera: CameraController {
        return cameraController
    }
}

