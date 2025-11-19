//
//  WorkflowCompiler.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Compiles YAML workflows to JSON plans via Apple's on-device SystemLanguageModel
class WorkflowCompiler {
    static let shared = WorkflowCompiler()
    
    @available(iOS 26.0, *)
    private var appleLanguageModelService: AppleLanguageModelService {
        AppleLanguageModelService.shared
    }
    
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
        
        print("🔨 [WorkflowCompiler] No cached plan found, compiling via Apple Intelligence...")
        
        // Compile via Apple Language Model (or fallback to Gemini if FoundationModels not available)
        do {
            var plan: WorkflowPlan
            if #available(iOS 18.0, *) {
                // AppleLanguageModelService will use FoundationModels if available (iOS 26+),
                // otherwise falls back to GeminiService
                if #available(iOS 26.0, *) {
                    do {
                        plan = try await appleLanguageModelService.compileWorkflow(yamlContent)
                    } catch {
                        // If FoundationModels API fails, fall back to Gemini
                        print("⚠️ [WorkflowCompiler] FoundationModels failed, falling back to Gemini: \(error)")
                        plan = try await GeminiService.shared.compileWorkflow(yamlContent)
                    }
                } else {
                    // Fallback to Gemini on earlier versions
                    print("🔨 [WorkflowCompiler] Using GeminiService (FoundationModels requires iOS 26+)")
                    plan = try await GeminiService.shared.compileWorkflow(yamlContent)
                }
            } else {
                throw WorkflowCompilerError.unsupportedVersion("iOS 18.0 or later is required")
            }
            print("✅ [WorkflowCompiler] Apple Intelligence compilation successful")
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

enum WorkflowCompilerError: LocalizedError {
    case unsupportedVersion(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let message):
            return message
        }
    }
}

