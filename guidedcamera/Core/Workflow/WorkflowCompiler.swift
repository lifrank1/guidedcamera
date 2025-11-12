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
        print("🔨 [WorkflowCompiler] Starting compilation...")
        print("🔨 [WorkflowCompiler] YAML content length: \(yamlContent.count) characters")
        
        // Check cache first
        let cacheId = cache.generateCacheIdentifier(from: yamlContent)
        print("🔨 [WorkflowCompiler] Cache ID: \(cacheId)")
        
        if let cached = cache.getCachedPlan(for: cacheId) {
            print("✅ [WorkflowCompiler] Found cached plan with \(cached.steps.count) steps")
            return cached
        }
        
        print("🔨 [WorkflowCompiler] No cached plan found, compiling via Gemini API...")
        
        // Compile via Gemini
        do {
            var plan = try await geminiService.compileWorkflow(yamlContent)
            print("✅ [WorkflowCompiler] Gemini compilation successful")
            print("✅ [WorkflowCompiler] Plan ID: \(plan.planId)")
            print("✅ [WorkflowCompiler] Steps count: \(plan.steps.count)")
            
            // Add ID for caching
            plan = WorkflowPlan(
                id: cacheId,
                planId: plan.planId,
                steps: plan.steps,
                report: plan.report,
                advice: plan.advice
            )
            
            print("🔨 [WorkflowCompiler] Validating and fixing compiled plan...")
            // Validate basic structure
            try validator.validate(plan)
            // Auto-fix invalid transitions
            plan = validator.validateAndFix(plan)
            print("✅ [WorkflowCompiler] Plan validation and fixing successful")
            
            // Cache the compiled plan
            print("🔨 [WorkflowCompiler] Caching compiled plan...")
            try cache.cachePlan(plan, for: cacheId)
            print("✅ [WorkflowCompiler] Plan cached successfully")
            
            return plan
        } catch {
            print("❌ [WorkflowCompiler] Compilation failed: \(error)")
            print("❌ [WorkflowCompiler] Error details: \(error.localizedDescription)")
            throw error
        }
    }
}

