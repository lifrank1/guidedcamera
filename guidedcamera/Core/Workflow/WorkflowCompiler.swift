//
//  WorkflowCompiler.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Compiles YAML workflows to JSON plans via Gemini API
class WorkflowCompiler {
    static let shared = WorkflowCompiler()
    
    private let geminiService = GeminiService.shared
    private let cache = WorkflowCache.shared
    private let validator = WorkflowValidator.shared
    
    private init() {}
    
    /// Compile a YAML workflow to a JSON plan
    func compile(_ yamlContent: String) async throws -> WorkflowPlan {
        // Check cache first
        let cacheId = cache.generateCacheIdentifier(from: yamlContent)
        if let cached = cache.getCachedPlan(for: cacheId) {
            return cached
        }
        
        // Compile via Gemini
        var plan = try await geminiService.compileWorkflow(yamlContent)
        
        // Add ID for caching
        plan = WorkflowPlan(
            id: cacheId,
            planId: plan.planId,
            steps: plan.steps,
            report: plan.report,
            advice: plan.advice
        )
        
        // Validate the compiled plan
        try validator.validate(plan)
        
        // Cache the compiled plan
        try cache.cachePlan(plan, for: cacheId)
        
        return plan
    }
}

