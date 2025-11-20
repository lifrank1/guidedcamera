//
//  GuidanceCoordinator.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Coordinates visual and voice guidance based on workflow step
@MainActor
class GuidanceCoordinator {
    static let shared = GuidanceCoordinator()
    
    private let voiceEngine = VoiceGuidanceEngine.shared
    
    private init() {}
    
    /// Provide guidance for a step
    func provideGuidance(for step: WorkflowStep) {
        // Speak the instruction
        voiceEngine.speak(step.ui.instruction)
    }
    
    /// Provide feedback after validation
    func provideFeedback(success: Bool, errors: [String] = []) {
        if success {
            voiceEngine.speak("Moving on.")
        } else {
            let errorMessage = errors.isEmpty ? "Please try again." : errors.joined(separator: ". ")
            voiceEngine.speak("\(errorMessage)")
        }
    }
    
    /// Stop current guidance
    func stop() {
        voiceEngine.stop()
    }
}

