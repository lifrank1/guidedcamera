//
//  CaptureSession.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import Combine

/// State machine managing workflow progress
class CaptureSession: ObservableObject {
    @Published var state: SessionState
    
    private let persistence = SessionPersistence.shared
    
    init(state: SessionState = SessionState()) {
        self.state = state
    }
    
    /// Start a new session with a workflow plan
    func start(with plan: WorkflowPlan) {
        state.workflowPlan = plan
        state.currentStepIndex = 0
        state.state = .active
        state.startedAt = Date()
        saveState()
    }
    
    /// Get current step
    var currentStep: WorkflowStep? {
        guard let plan = state.workflowPlan,
              state.currentStepIndex < plan.steps.count else {
            return nil
        }
        return plan.steps[state.currentStepIndex]
    }
    
    /// Move to next step
    func nextStep(transition: TransitionCondition = .onSuccess) {
        guard let plan = state.workflowPlan,
              let currentStep = currentStep else {
            return
        }
        
        // Find transition for the condition
        let transition = currentStep.transitions.first { $0.when == transition }
        let nextStepId = transition?.to
        
        if let nextStepId = nextStepId,
           let nextIndex = plan.steps.firstIndex(where: { $0.id == nextStepId }) {
            state.currentStepIndex = nextIndex
        } else {
            // Default: move to next step in sequence
            if state.currentStepIndex < plan.steps.count - 1 {
                state.currentStepIndex += 1
            } else {
                complete()
            }
        }
        
        saveState()
    }
    
    /// Skip current step
    func skipStep() {
        nextStep(transition: .onSkip)
    }
    
    /// Retry current step
    func retryStep() {
        // Remove media captured for this step
        if let currentStep = currentStep {
            state.capturedMedia.removeAll { $0.stepId == currentStep.id }
        }
        saveState()
    }
    
    /// Pause session
    func pause() {
        state.state = .paused
        saveState()
    }
    
    /// Resume session
    func resume() {
        state.state = .active
        saveState()
    }
    
    /// Complete session
    func complete() {
        state.state = .completed
        state.completedAt = Date()
        saveState()
    }
    
    /// Add captured media
    func addMedia(_ media: CapturedMedia) {
        state.capturedMedia.append(media)
        saveState()
    }
    
    /// Add annotation
    func addAnnotation(_ annotation: Annotation) {
        state.annotations.append(annotation)
        saveState()
    }
    
    /// Check if session is complete
    var isComplete: Bool {
        state.state == .completed
    }
    
    /// Get progress (0.0 to 1.0)
    var progress: Double {
        guard let plan = state.workflowPlan,
              !plan.steps.isEmpty else {
            return 0.0
        }
        return Double(state.currentStepIndex) / Double(plan.steps.count)
    }
    
    private func saveState() {
        try? persistence.save(state)
    }
}

