//
//  SessionState.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Current session state and progress
struct SessionState: Codable {
    var workflowPlan: WorkflowPlan?
    var currentStepIndex: Int
    var state: SessionStateType
    var capturedMedia: [CapturedMedia]
    var annotations: [Annotation]
    var startedAt: Date?
    var completedAt: Date?
    
    init() {
        self.currentStepIndex = 0
        self.state = .idle
        self.capturedMedia = []
        self.annotations = []
    }
}

enum SessionStateType: String, Codable {
    case idle
    case active
    case paused
    case completed
}

