//
//  Report.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Represents a completed workflow report
struct Report: Codable, Identifiable {
    let id: UUID
    let workflowName: String
    let completedAt: Date
    let generatedAt: Date
    let sessionState: SessionState
    
    init(id: UUID = UUID(), workflowName: String, completedAt: Date, generatedAt: Date = Date(), sessionState: SessionState) {
        self.id = id
        self.workflowName = workflowName
        self.completedAt = completedAt
        self.generatedAt = generatedAt
        self.sessionState = sessionState
    }
}

