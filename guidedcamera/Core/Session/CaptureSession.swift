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
        // If session is completed, don't return a step
        guard state.state != .completed else {
            print("🔍 [CaptureSession] currentStep: Session is completed, returning nil")
            return nil
        }
        
        guard let plan = state.workflowPlan else {
            print("🔍 [CaptureSession] currentStep: No workflow plan")
            return nil
        }
        print("🔍 [CaptureSession] currentStep: currentStepIndex=\(state.currentStepIndex), totalSteps=\(plan.steps.count), state=\(state.state)")
        if state.currentStepIndex < plan.steps.count {
            let step = plan.steps[state.currentStepIndex]
            print("🔍 [CaptureSession] currentStep: Returning step '\(step.id)' at index \(state.currentStepIndex)")
            return step
        } else {
            print("🔍 [CaptureSession] currentStep: Index \(state.currentStepIndex) >= totalSteps \(plan.steps.count), returning nil")
            return nil
        }
    }
    
    /// Move to next step
    func nextStep(transition: TransitionCondition = .onSuccess) {
        print("🔄 [CaptureSession] nextStep() called with transition: \(transition)")
        guard let plan = state.workflowPlan else {
            print("❌ [CaptureSession] nextStep: No workflow plan")
            return
        }
        
        print("🔄 [CaptureSession] nextStep: currentStepIndex=\(state.currentStepIndex), totalSteps=\(plan.steps.count)")
        
        guard let currentStep = currentStep else {
            print("❌ [CaptureSession] nextStep: No current step (currentStepIndex=\(state.currentStepIndex))")
            return
        }
        
        print("🔄 [CaptureSession] nextStep: Current step is '\(currentStep.id)' at index \(state.currentStepIndex)")
        print("🔄 [CaptureSession] nextStep: Current step has \(currentStep.transitions.count) transitions")
        
        // Find transition for the condition
        let transition = currentStep.transitions.first { $0.when == transition }
        let nextStepId = transition?.to
        
        if let nextStepId = nextStepId {
            print("🔄 [CaptureSession] nextStep: Found transition to '\(nextStepId)'")
            if let nextIndex = plan.steps.firstIndex(where: { $0.id == nextStepId }) {
                print("🔄 [CaptureSession] nextStep: Transitioning to step '\(nextStepId)' at index \(nextIndex)")
                state.currentStepIndex = nextIndex
            } else {
                print("⚠️ [CaptureSession] nextStep: Transition points to non-existent step '\(nextStepId)', using default behavior")
                // Default: move to next step in sequence
                if state.currentStepIndex < plan.steps.count - 1 {
                    let newIndex = state.currentStepIndex + 1
                    print("🔄 [CaptureSession] nextStep: Moving to next step in sequence: index \(newIndex)")
                    state.currentStepIndex = newIndex
                } else {
                    print("✅ [CaptureSession] nextStep: Already at last step, completing session")
                    complete()
                }
            }
        } else {
            print("🔄 [CaptureSession] nextStep: No transition found for \(transition), using default behavior")
            // Default: move to next step in sequence
            if state.currentStepIndex < plan.steps.count - 1 {
                let newIndex = state.currentStepIndex + 1
                print("🔄 [CaptureSession] nextStep: Moving to next step in sequence: index \(newIndex)")
                state.currentStepIndex = newIndex
            } else {
                print("✅ [CaptureSession] nextStep: Already at last step (index \(state.currentStepIndex) of \(plan.steps.count - 1)), completing session")
                complete()
            }
        }
        
        print("🔄 [CaptureSession] nextStep: After transition, currentStepIndex=\(state.currentStepIndex)")
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
        print("✅ [CaptureSession] complete() called")
        print("✅ [CaptureSession] complete: Current state=\(state.state), currentStepIndex=\(state.currentStepIndex)")
        if let plan = state.workflowPlan {
            print("✅ [CaptureSession] complete: Total steps=\(plan.steps.count)")
        }
        state.state = .completed
        state.completedAt = Date()
        print("✅ [CaptureSession] complete: Session marked as completed")
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

