//
//  VoiceGuidanceEngine.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import AVFoundation

/// Manages AVSpeechSynthesizer for TTS instructions
@MainActor
class VoiceGuidanceEngine: NSObject, ObservableObject {
    static let shared = VoiceGuidanceEngine()
    
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Speak an instruction
    func speak(_ text: String, language: String = "en-US") {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    /// Stop speaking
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension VoiceGuidanceEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

