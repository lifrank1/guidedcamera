//
//  SpeechRecognizer.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import Speech

/// Wraps SFSpeechRecognizer for STT
class SpeechRecognizer: NSObject, ObservableObject {
    static let shared = SpeechRecognizer()
    
    @Published var isAuthorized = false
    @Published var isRecognizing = false
    
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private override init() {
        super.init()
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = status == .authorized
            }
        }
    }
    
    /// Start speech recognition
    func startRecognition(completion: @escaping (Result<String, Error>) -> Void) {
        guard isAuthorized else {
            completion(.failure(SpeechError.notAuthorized))
            return
        }
        
        guard let recognizer = recognizer, recognizer.isAvailable else {
            completion(.failure(SpeechError.notAvailable))
            return
        }
        
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            completion(.failure(SpeechError.setupFailed))
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let result = result {
                if result.isFinal {
                    completion(.success(result.bestTranscription.formattedString))
                }
            }
        }
        
        // Setup audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecognizing = true
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Stop speech recognition
    func stopRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecognizing = false
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

enum SpeechError: LocalizedError {
    case notAuthorized
    case notAvailable
    case setupFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .notAvailable:
            return "Speech recognition not available"
        case .setupFailed:
            return "Failed to set up speech recognition"
        }
    }
}

