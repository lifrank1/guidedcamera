//
//  AudioRecordingManager.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import AVFoundation

/// Manages audio recording for voice annotations
@MainActor
class AudioRecordingManager: NSObject, ObservableObject {
    static let shared = AudioRecordingManager()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    // Remove max duration limit for continuous recording
    // private let maxRecordingDuration: TimeInterval = 60.0
    
    // Continuous recording support
    private var segmentStartTimes: [String: Date] = [:] // stepId -> start time
    private var currentStepId: String?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    /// Setup audio session for recording
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("❌ [AudioRecordingManager] Failed to setup audio session: \(error)")
        }
    }
    
    /// Start recording audio
    func startRecording() throws {
        guard !isRecording else {
            print("⚠️ [AudioRecordingManager] Already recording")
            return
        }
        
        // Check microphone permission
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission
        guard permissionStatus == .granted else {
            throw AudioRecordingError.permissionDenied
        }
        
        // Create temporary file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "voice_annotation_\(UUID().uuidString).m4a"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        guard let url = recordingURL else {
            throw AudioRecordingError.fileCreationFailed
        }
        
        // Configure audio recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
            recordingDuration = 0
            
            // Start timer to track duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.recordingDuration += 0.1
                }
            }
            
            print("✅ [AudioRecordingManager] Started recording to: \(url.path)")
        } catch {
            print("❌ [AudioRecordingManager] Failed to start recording: \(error)")
            throw AudioRecordingError.recordingFailed(error.localizedDescription)
        }
    }
    
    /// Stop recording
    func stopRecording() {
        guard isRecording else {
            print("⚠️ [AudioRecordingManager] Not recording")
            return
        }
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        
        print("✅ [AudioRecordingManager] Stopped recording, duration: \(recordingDuration)s")
    }
    
    /// Mark the start of a new step segment (for continuous recording)
    func markStepStart(_ stepId: String) {
        segmentStartTimes[stepId] = Date()
        currentStepId = stepId
        print("🎙️ [AudioRecordingManager] Marked step start: \(stepId)")
    }
    
    /// Get the audio segment for a specific step (returns the full recording if continuous)
    func getRecordingURL() -> URL? {
        guard let url = recordingURL else {
            return nil
        }
        
        // If still recording, return current file
        if isRecording {
            return url
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ [AudioRecordingManager] Recording file does not exist")
            return nil
        }
        
        return url
    }
    
    /// Get recording URL for a specific step segment
    func getRecordingURL(for stepId: String) -> URL? {
        // For now, return the full recording URL
        // In a more advanced implementation, we could extract segments
        return getRecordingURL()
    }
    
    
    /// Clean up recording file
    func cleanup() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
        recordingDuration = 0
        segmentStartTimes.removeAll()
        currentStepId = nil
    }
    
    /// Clean up and reset for new session
    func reset() {
        stopRecording()
        cleanup()
    }
}

extension AudioRecordingManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("⚠️ [AudioRecordingManager] Recording finished unsuccessfully")
            }
            isRecording = false
            recordingTimer?.invalidate()
            recordingTimer = nil
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("❌ [AudioRecordingManager] Recording error: \(error?.localizedDescription ?? "Unknown")")
            isRecording = false
            recordingTimer?.invalidate()
            recordingTimer = nil
        }
    }
}

enum AudioRecordingError: LocalizedError {
    case permissionDenied
    case fileCreationFailed
    case recordingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record voice annotations"
        case .fileCreationFailed:
            return "Failed to create recording file"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        }
    }
}

