//
//  ReportGenerator.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Generates reports from completed workflow sessions
class ReportGenerator {
    static let shared = ReportGenerator()
    
    private init() {}
    
    /// Generate a report from a completed session state
    func generateReport(from sessionState: SessionState, workflowName: String) -> Report {
        let completedAt = sessionState.completedAt ?? Date()
        
        let report = Report(
            workflowName: workflowName,
            completedAt: completedAt,
            generatedAt: Date(),
            sessionState: sessionState
        )
        
        print("✅ [ReportGenerator] Generated report for workflow: \(workflowName)")
        print("   - Completed at: \(completedAt)")
        print("   - Media count: \(sessionState.capturedMedia.count)")
        print("   - Annotations count: \(sessionState.annotations.count)")
        
        return report
    }
}

