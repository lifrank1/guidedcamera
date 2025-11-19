//
//  AppleLanguageModelService.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Service for interacting with Apple's on-device SystemLanguageModel
/// Note: FoundationModels framework requires iOS 26+ and Apple Intelligence enabled
/// When not available, falls back to GeminiService
@available(iOS 26.0, *)
class AppleLanguageModelService {
    static let shared = AppleLanguageModelService()
    
    private let model = SystemLanguageModel.default
    
    private init() {}
    
    /// Compile YAML workflow to JSON plan using Apple's SystemLanguageModel
    func compileWorkflow(_ yamlContent: String) async throws -> WorkflowPlan {
        print("🍎 [AppleLanguageModelService] Starting workflow compilation...")
        print("🍎 [AppleLanguageModelService] YAML content length: \(yamlContent.count) characters")
        
        // Check locale support (recommended by Apple documentation)
        let currentLocale = Locale.current
        if !model.supportsLocale(currentLocale) {
            print("⚠️ [AppleLanguageModelService] Current locale \(currentLocale.identifier) may not be fully supported")
            // Continue anyway as English is typically supported
        }
        
        // Check model availability
        let availability = await model.availability
        print("🍎 [AppleLanguageModelService] Model availability: \(availability)")
        
        // Handle availability according to SystemLanguageModel.Availability enum
        // Based on Apple documentation: .available, .unavailable(.deviceNotEligible), 
        // .unavailable(.appleIntelligenceNotEnabled), .unavailable(.modelNotReady)
        switch availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible):
            throw AppleLanguageModelError.notEligible("Device is not eligible for Apple Intelligence")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw AppleLanguageModelError.notEnabled("Apple Intelligence is not enabled. Please enable it in Settings.")
        case .unavailable(.modelNotReady):
            throw AppleLanguageModelError.notReady("Model is not ready. Please try again in a moment.")
        case .unavailable(let other):
            throw AppleLanguageModelError.unavailable("Model is unavailable: \(other)")
        @unknown default:
            throw AppleLanguageModelError.unavailable("Model is unavailable for unknown reasons")
        }
        
        // Create a focused prompt that emphasizes JSON-only output
        // Put instructions in the session instructions, keep prompt minimal
        let prompt = """
        Convert this YAML workflow to JSON. Output ONLY the JSON object, nothing else.

        \(yamlContent)
        """
        
        print("🍎 [AppleLanguageModelService] Generating content with SystemLanguageModel...")
        
        do {
            // Create a session with instructions for the model
            // Instructions help steer the model to output JSON format
            let instructions = """
            You are a YAML-to-JSON compiler for a guided camera iOS app. Convert YAML workflows to JSON plans.
            
            Output structure:
            {
              "plan_id": "workflow_name_v1",
              "steps": [
                {
                  "id": "step_id",
                  "ui": {
                    "instruction": "Clear instruction text",
                    "overlays": ["grid", "horizon"]
                  },
                  "capture": {
                    "type": "photo" or "video",
                    "minCount": 1
                  },
                  "validators": [
                    {
                      "name": "sharpness",
                      "op": ">=",
                      "value": 0.4
                    },
                    {
                      "name": "contains",
                      "args": {
                        "labelsAnyOf": ["house", "building"]
                      }
                    }
                  ],
                  "transitions": [
                    {
                      "when": "onSuccess",
                      "to": "next_step_id"
                    },
                    {
                      "when": "onSkip",
                      "to": "next_step_id"
                    }
                  ]
                }
              ],
              "report": {
                "template": "inspection_basic"
              },
              "advice": []
            }
            
            Rules:
            - Map human phrases to known overlays: "grid", "horizon", "rule_of_thirds"
            - Expand vague conditions like "must_have: [house]" into formal validator checks
            - Resolve transitions into deterministic state links
            - Fill in defaults (minCount: 1 if not specified)
            - CRITICAL: All transition "to" values MUST reference actual step IDs from the steps array
            - DO NOT create transitions to non-existent steps
            - Output ONLY valid JSON, no markdown code blocks, no explanations, no preamble
            """
            
            let session = LanguageModelSession(instructions: instructions)
            print("🍎 [AppleLanguageModelService] Created LanguageModelSession")
            
            // Configure generation options for structured JSON output
            // Temperature controls randomness: lower = more deterministic, higher = more creative
            // For YAML-to-JSON compilation, we want low temperature (0.0-0.3) for consistent, structured output
            // This ensures the model produces reliable JSON that matches the expected schema
            let options = GenerationOptions(temperature: 0.1)
            
            // Generate a response using the session with generation options
            // According to FoundationModels documentation: session.respond(to:options:)
            // Returns LanguageModelSession.Response<String> which has a .content property
            let response = try await session.respond(to: prompt, options: options)
            print("🍎 [AppleLanguageModelService] Received response from model")
            
            // Extract text from the response - Response<String> has a .content property
            let text = response.content
            print("🍎 [AppleLanguageModelService] Successfully extracted text from response")
            
            print("🍎 [AppleLanguageModelService] Extracted text from response, length: \(text.count) characters")
            print("🍎 [AppleLanguageModelService] Text preview: \(text.prefix(200))...")
            
            // Extract JSON from response
            // The model might return the prompt + JSON, or just JSON, or JSON in markdown
            var jsonString = extractJSON(from: text)
            
            // If the response contains the prompt text, try to extract just the JSON portion
            // Look for the first occurrence of a JSON object (starts with {)
            if jsonString.contains("You are a YAML-to-JSON compiler") || jsonString.contains("YAML to compile") {
                print("⚠️ [AppleLanguageModelService] Response contains prompt text, extracting JSON portion...")
                // Find the first { that starts a JSON object
                if let jsonStartIndex = jsonString.firstIndex(of: "{") {
                    let jsonPortion = String(jsonString[jsonStartIndex...])
                    // Find the matching closing brace for the root object
                    var braceCount = 0
                    var jsonEndIndex = jsonPortion.endIndex
                    for (index, char) in jsonPortion.enumerated() {
                        if char == "{" {
                            braceCount += 1
                        } else if char == "}" {
                            braceCount -= 1
                            if braceCount == 0 {
                                jsonEndIndex = jsonPortion.index(jsonPortion.startIndex, offsetBy: index + 1)
                                break
                            }
                        }
                    }
                    jsonString = String(jsonPortion[..<jsonEndIndex])
                    print("🍎 [AppleLanguageModelService] Extracted JSON from response with prompt text")
                }
            }
            
            print("🍎 [AppleLanguageModelService] Extracted JSON string, length: \(jsonString.count) characters")
            print("🍎 [AppleLanguageModelService] JSON preview: \(jsonString.prefix(200))...")
            
            guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
                print("❌ [AppleLanguageModelService] Failed to convert JSON string to data")
                throw AppleLanguageModelError.invalidResponse("Failed to convert JSON string to data")
            }
            
            print("🍎 [AppleLanguageModelService] Decoding JSON to WorkflowPlan...")
            let decoder = JSONDecoder()
            do {
                let plan = try decoder.decode(WorkflowPlan.self, from: jsonData)
                print("✅ [AppleLanguageModelService] Successfully decoded WorkflowPlan")
                print("✅ [AppleLanguageModelService] Plan ID: \(plan.planId), Steps: \(plan.steps.count)")
                return plan
            } catch let decodingError as DecodingError {
                print("❌ [AppleLanguageModelService] JSON Decoding Error:")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("❌ [AppleLanguageModelService] Type mismatch: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("❌ [AppleLanguageModelService] Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("❌ [AppleLanguageModelService] Value not found: \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("❌ [AppleLanguageModelService] Context: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("❌ [AppleLanguageModelService] Key not found: \(key.stringValue) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("❌ [AppleLanguageModelService] Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("❌ [AppleLanguageModelService] Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("❌ [AppleLanguageModelService] Context: \(context.debugDescription)")
                @unknown default:
                    print("❌ [AppleLanguageModelService] Unknown decoding error: \(decodingError)")
                }
                print("❌ [AppleLanguageModelService] Full JSON that failed to decode:")
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
                throw AppleLanguageModelError.invalidResponse("Failed to decode JSON response: \(decodingError.localizedDescription)")
            } catch {
                print("❌ [AppleLanguageModelService] Unexpected decoding error: \(error)")
                print("❌ [AppleLanguageModelService] Full JSON that failed to decode:")
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
                throw error
            }
            
        } catch let error as AppleLanguageModelError {
            print("❌ [AppleLanguageModelService] AppleLanguageModelError: \(error)")
            throw error
        } catch {
            print("❌ [AppleLanguageModelService] Unexpected error: \(error)")
            throw AppleLanguageModelError.apiError("Model error: \(error.localizedDescription)")
        }
    }
    
    /// Extract JSON from text that may contain markdown code blocks
    private func extractJSON(from text: String) -> String {
        // Remove markdown code blocks if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#else
// Fallback implementation when FoundationModels is not available
/// Service for interacting with Apple's on-device SystemLanguageModel
/// Note: FoundationModels framework is not available. This falls back to GeminiService.
@available(iOS 18.0, *)
class AppleLanguageModelService {
    static let shared = AppleLanguageModelService()
    
    private init() {}
    
    /// Compile YAML workflow to JSON plan
    /// Falls back to GeminiService when FoundationModels is not available
    func compileWorkflow(_ yamlContent: String) async throws -> WorkflowPlan {
        print("⚠️ [AppleLanguageModelService] FoundationModels not available (requires iOS 26+), falling back to GeminiService")
        // Fallback to GeminiService when FoundationModels is not available
        return try await GeminiService.shared.compileWorkflow(yamlContent)
    }
}

#endif

enum AppleLanguageModelError: LocalizedError, Equatable {
    case notEligible(String)
    case notEnabled(String)
    case notReady(String)
    case unavailable(String)
    case apiError(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .notEligible(let message):
            return "Apple Intelligence not eligible: \(message)"
        case .notEnabled(let message):
            return "Apple Intelligence not enabled: \(message)"
        case .notReady(let message):
            return "Model not ready: \(message)"
        case .unavailable(let message):
            return "Model unavailable: \(message)"
        case .apiError(let message):
            return "Apple Language Model error: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from model: \(message)"
        }
    }
    
    static func == (lhs: AppleLanguageModelError, rhs: AppleLanguageModelError) -> Bool {
        switch (lhs, rhs) {
        case (.notEligible(let lhsMsg), .notEligible(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.notEnabled(let lhsMsg), .notEnabled(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.notReady(let lhsMsg), .notReady(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.unavailable(let lhsMsg), .unavailable(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.apiError(let lhsMsg), .apiError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.invalidResponse(let lhsMsg), .invalidResponse(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

