//
//  WorkflowValidator.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Validates compiled workflow plans before execution
class WorkflowValidator {
    static let shared = WorkflowValidator()
    
    private init() {}
    
    /// Validate a compiled workflow plan (throws on critical errors)
    func validate(_ plan: WorkflowPlan) throws {
        print("🔍 [WorkflowValidator] Validating workflow plan...")
        
        // Validate plan has steps
        guard !plan.steps.isEmpty else {
            throw ValidationError.emptyPlan
        }
        
        // Validate step IDs are unique
        let stepIds = plan.steps.map { $0.id }
        let uniqueIds = Set(stepIds)
        guard stepIds.count == uniqueIds.count else {
            throw ValidationError.duplicateStepIds
        }
        
        print("🔍 [WorkflowValidator] Step IDs are unique: \(stepIds)")
        
        // Validate each step
        for (index, step) in plan.steps.enumerated() {
            try validateStep(step, at: index, totalSteps: plan.steps.count)
        }
        
        print("✅ [WorkflowValidator] Basic validation complete")
    }
    
    /// Validate and return a fixed plan with corrected transitions
    func validateAndFix(_ plan: WorkflowPlan) -> WorkflowPlan {
        print("🔍 [WorkflowValidator] Validating and fixing workflow plan...")
        
        // Validate plan has steps
        guard !plan.steps.isEmpty else {
            return plan // Can't fix empty plan
        }
        
        // Validate step IDs are unique
        let stepIds = plan.steps.map { $0.id }
        let uniqueIds = Set(stepIds)
        guard stepIds.count == uniqueIds.count else {
            return plan // Can't fix duplicate IDs
        }
        
        print("🔍 [WorkflowValidator] Step IDs are unique: \(stepIds)")
        
        // Validate each step and auto-fix invalid transitions
        var fixedSteps: [WorkflowStep] = []
        for (index, step) in plan.steps.enumerated() {
            // Auto-fix invalid transitions
            let validTransitions = step.transitions.filter { transition in
                let isValid = plan.steps.contains(where: { $0.id == transition.to })
                if !isValid {
                    print("⚠️ [WorkflowValidator] Step '\(step.id)' has invalid transition to '\(transition.to)' - removing it")
                }
                return isValid
            }
            
            // If all transitions were invalid, add a default transition to the next step (or complete)
            let finalTransitions: [Transition]
            if validTransitions.isEmpty {
                print("⚠️ [WorkflowValidator] Step '\(step.id)' has no valid transitions - adding default")
                if index < plan.steps.count - 1 {
                    // Transition to next step in sequence
                    let nextStepId = plan.steps[index + 1].id
                    finalTransitions = [
                        Transition(when: .onSuccess, to: nextStepId),
                        Transition(when: .onSkip, to: nextStepId)
                    ]
                } else {
                    // Last step - no transitions needed (will complete naturally)
                    finalTransitions = []
                }
            } else {
                finalTransitions = validTransitions
            }
            
            // Create fixed step
            let fixedStep = WorkflowStep(
                id: step.id,
                ui: step.ui,
                capture: step.capture,
                validators: step.validators,
                transitions: finalTransitions
            )
            fixedSteps.append(fixedStep)
        }
        
        // Return fixed plan
        let fixedPlan = WorkflowPlan(
            id: plan.id,
            planId: plan.planId,
            steps: fixedSteps,
            report: plan.report,
            advice: plan.advice
        )
        
        print("✅ [WorkflowValidator] Fixed \(plan.steps.count - fixedSteps.count) invalid transitions.")
        return fixedPlan
    }
    
    private func validateStep(_ step: WorkflowStep, at index: Int, totalSteps: Int) throws {
        // Validate step has instruction
        guard !step.ui.instruction.isEmpty else {
            throw ValidationError.missingInstruction(at: index)
        }
        
        // Validate capture type
        guard step.capture.type == .photo || step.capture.type == .video else {
            throw ValidationError.invalidCaptureType(at: index)
        }
        
        // Validate transitions (last step can have empty transitions - will complete naturally)
        let isLastStep = index == totalSteps - 1
        if !isLastStep && step.transitions.isEmpty {
            throw ValidationError.missingTransitions(at: index)
        }
        // Last step can have empty transitions - that's fine, session will complete
    }
}

enum ValidationError: LocalizedError {
    case emptyPlan
    case duplicateStepIds
    case invalidTransition(String)
    case missingInstruction(at: Int)
    case invalidCaptureType(at: Int)
    case missingTransitions(at: Int)
    
    var errorDescription: String? {
        switch self {
        case .emptyPlan:
            return "Workflow plan has no steps"
        case .duplicateStepIds:
            return "Workflow plan contains duplicate step IDs"
        case .invalidTransition(let stepId):
            return "Transition references invalid step ID: \(stepId)"
        case .missingInstruction(let index):
            return "Step at index \(index) is missing instruction"
        case .invalidCaptureType(let index):
            return "Step at index \(index) has invalid capture type"
        case .missingTransitions(let index):
            return "Step at index \(index) has no transitions"
        }
    }
}

