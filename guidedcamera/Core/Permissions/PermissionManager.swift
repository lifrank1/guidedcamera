//
//  PermissionManager.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import AVFoundation
import Speech
import CoreLocation

/// Manages app permissions
class PermissionManager {
    static let shared = PermissionManager()
    
    private let locationManager = CLLocationManager()
    
    private init() {}
    
    /// Request all necessary permissions
    func requestAllPermissions() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.requestCameraPermission()
            }
            group.addTask {
                await self.requestMicrophonePermission()
            }
            group.addTask {
                await self.requestSpeechRecognitionPermission()
            }
            group.addTask {
                await self.requestLocationPermission()
            }
        }
    }
    
    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
    
    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
    
    /// Request speech recognition permission
    func requestSpeechRecognitionPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default:
            return false
        }
    }
    
    /// Request location permission
    func requestLocationPermission() async -> Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.locationManager.requestWhenInUseAuthorization()
                // Wait a bit for the authorization to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    continuation.resume(returning: self.locationManager.authorizationStatus == .authorizedWhenInUse || self.locationManager.authorizationStatus == .authorizedAlways)
                }
            }
        default:
            return false
        }
    }
}

