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
    
    /// Validate a compiled workflow plan
    func validate(_ plan: WorkflowPlan) throws {
        // Validate plan has steps
        guard !plan.steps.isEmpty else {
            throw ValidationError.emptyPlan
        }
        
        // Validate each step
        for (index, step) in plan.steps.enumerated() {
            try validateStep(step, at: index)
        }
        
        // Validate step IDs are unique
        let stepIds = plan.steps.map { $0.id }
        let uniqueIds = Set(stepIds)
        guard stepIds.count == uniqueIds.count else {
            throw ValidationError.duplicateStepIds
        }
        
        // Validate transitions reference valid step IDs
        for step in plan.steps {
            for transition in step.transitions {
                guard plan.steps.contains(where: { $0.id == transition.to }) else {
                    throw ValidationError.invalidTransition(transition.to)
                }
            }
        }
    }
    
    private func validateStep(_ step: WorkflowStep, at index: Int) throws {
        // Validate step has instruction
        guard !step.ui.instruction.isEmpty else {
            throw ValidationError.missingInstruction(at: index)
        }
        
        // Validate capture type
        guard step.capture.type == .photo || step.capture.type == .video else {
            throw ValidationError.invalidCaptureType(at: index)
        }
        
        // Validate at least one transition
        guard !step.transitions.isEmpty else {
            throw ValidationError.missingTransitions(at: index)
        }
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

