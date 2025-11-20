//
//  SpeechRecognitionService.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import Speech
import AVFoundation

/// Service for converting speech to text using SFSpeechRecognizer
@MainActor
class SpeechRecognitionService: ObservableObject {
    static let shared = SpeechRecognitionService()
    
    @Published var isTranscribing = false
    @Published var transcriptionText: String?
    @Published var currentTranscription: String = "" // Real-time transcription text
    
    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private init() {
        // Initialize with default locale, fallback to English if not available
        recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    /// Check if speech recognition is available
    var isAvailable: Bool {
        guard let recognizer = recognizer else { return false }
        return recognizer.isAvailable
    }
    
    /// Check authorization status
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }
    
    /// Transcribe audio file to text
    func transcribe(audioFileURL: URL, locale: Locale? = nil) async throws -> String {
        print("🎤 [SpeechRecognitionService] Starting transcription for: \(audioFileURL.path)")
        
        guard let recognizer = recognizer else {
            throw SpeechRecognitionError.notAvailable
        }
        
        guard recognizer.isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }
        
        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        // Use provided locale or default
        let speechRecognizer = locale != nil ? SFSpeechRecognizer(locale: locale!) : recognizer
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }
        
        isTranscribing = true
        transcriptionText = nil
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
            request.shouldReportPartialResults = false
            
            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [SpeechRecognitionService] Recognition error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isTranscribing = false
                    }
                    continuation.resume(throwing: SpeechRecognitionError.transcriptionFailed(error.localizedDescription))
                    return
                }
                
                if let result = result {
                    if result.isFinal {
                        let transcribedText = result.bestTranscription.formattedString
                        print("✅ [SpeechRecognitionService] Transcription complete: \(transcribedText)")
                        Task { @MainActor in
                            self.isTranscribing = false
                            self.transcriptionText = transcribedText
                        }
                        continuation.resume(returning: transcribedText)
                    }
                }
            }
        }
    }
    
    /// Start real-time transcription using AVAudioEngine
    func startRealTimeTranscription() throws {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        // Stop any existing transcription
        stopRealTimeTranscription()
        
        // Reset transcription text
        currentTranscription = ""
        transcriptionText = nil
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        
        request.shouldReportPartialResults = true
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Prepare and start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("❌ [SpeechRecognitionService] Failed to start audio engine: \(error)")
            throw SpeechRecognitionError.setupFailed
        }
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [SpeechRecognitionService] Real-time recognition error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.isTranscribing = false
                }
                return
            }
            
            if let result = result {
                Task { @MainActor in
                    let text = result.bestTranscription.formattedString
                    self.currentTranscription = text
                    self.transcriptionText = text
                    
                    if result.isFinal {
                        // Final result - keep the text but don't stop transcribing
                        print("✅ [SpeechRecognitionService] Final transcription: \(text)")
                    }
                }
            }
        }
        
        isTranscribing = true
        print("✅ [SpeechRecognitionService] Started real-time transcription")
    }
    
    /// Pause real-time transcription (temporarily, can be resumed)
    func pauseRealTimeTranscription() {
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        print("⏸️ [SpeechRecognitionService] Paused real-time transcription")
    }
    
    /// Resume real-time transcription after pause
    func resumeRealTimeTranscription() throws {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        // Ensure audio engine is still running
        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
            print("▶️ [SpeechRecognitionService] Restarted audio engine")
        }
        
        // Create new recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        request.shouldReportPartialResults = true
        
        // Reinstall tap on input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [SpeechRecognitionService] Real-time recognition error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.isTranscribing = false
                }
                return
            }
            
            if let result = result {
                Task { @MainActor in
                    let text = result.bestTranscription.formattedString
                    self.currentTranscription = text
                    self.transcriptionText = text
                    
                    if result.isFinal {
                        print("✅ [SpeechRecognitionService] Final transcription: \(text)")
                    }
                }
            }
        }
        
        isTranscribing = true
        print("▶️ [SpeechRecognitionService] Resumed real-time transcription")
    }
    
    /// Stop real-time transcription
    func stopRealTimeTranscription() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
        print("✅ [SpeechRecognitionService] Stopped real-time transcription")
    }
    
    /// Get current transcription and reset for new segment
    func getCurrentTranscription() -> String {
        let text = currentTranscription
        currentTranscription = "" // Reset for next segment
        return text
    }
    
    /// Cancel current transcription
    func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
        transcriptionText = nil
    }
}

enum SpeechRecognitionError: LocalizedError {
    case notAvailable
    case notAuthorized
    case setupFailed
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Speech recognition is not available on this device"
        case .notAuthorized:
            return "Speech recognition permission is required"
        case .setupFailed:
            return "Failed to setup speech recognition"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

