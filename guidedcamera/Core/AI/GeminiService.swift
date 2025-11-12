//
//  GeminiService.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Service for interacting with Gemini API
class GeminiService {
    static let shared = GeminiService()
    
    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let key = plist["GeminiAPIKey"] as? String else {
            fatalError("Gemini API key not found in Config.plist")
        }
        return key
    }
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    
    private init() {}
    
    /// Compile YAML workflow to JSON plan using Gemini 2.5 Flash
    func compileWorkflow(_ yamlContent: String) async throws -> WorkflowPlan {
        print("🤖 [GeminiService] Starting workflow compilation...")
        print("🤖 [GeminiService] YAML content length: \(yamlContent.count) characters")
        
        let url = URL(string: "\(baseURL)/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!
        print("🤖 [GeminiService] API URL: \(url.absoluteString.replacingOccurrences(of: apiKey, with: "***"))")
        
        let prompt = """
        You are a YAML-to-JSON compiler for a guided camera iOS app. Your job is to normalize and constrain flexible YAML workflows into strict, executable JSON plans.

        The YAML workflow may contain free-form text or ambiguous keys. Transform it into a standardized JSON plan with this exact structure:

        {
          "plan_id": "workflow_name_v1",
          "steps": [
            {
              "id": "step_id",
              "ui": {
                "instruction": "Clear instruction text",
                "overlays": ["grid", "horizon"] // optional array
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
            "template": "inspection_basic" // optional
          },
          "advice": [] // optional array of warnings about unsupported features
        }

        Rules:
        - Map human phrases to known overlays: "grid", "horizon", "rule_of_thirds"
        - Expand vague conditions like "must_have: [house]" into formal validator checks
        - Resolve transitions into deterministic state links
        - Fill in defaults (minCount: 1 if not specified)
        - Emit advice[] for unsupported features
        - CRITICAL: All transition "to" values MUST reference actual step IDs from the steps array
        - DO NOT create transitions to non-existent steps like "plan_complete" or "workflow_complete"
        - For the last step, transitions can be empty or point to the previous step (but this is optional)
        - Output ONLY valid JSON, no markdown, no explanations

        YAML to compile:
        \(yamlContent)
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Retry logic with exponential backoff for rate limiting
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                print("🤖 [GeminiService] Attempt \(attempt + 1)/\(maxRetries): Sending request to Gemini API...")
                let (data, response) = try await URLSession.shared.data(for: request)
                print("🤖 [GeminiService] Received response, data size: \(data.count) bytes")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ [GeminiService] Invalid response type")
                    throw GeminiError.apiError("Invalid response")
                }
                
                print("🤖 [GeminiService] HTTP Status Code: \(httpResponse.statusCode)")
                
                // Handle rate limiting (429)
                if httpResponse.statusCode == 429 {
                    if attempt < maxRetries - 1 {
                        // Exponential backoff: 2^attempt seconds
                        let delay = pow(2.0, Double(attempt))
                        print("⚠️ [GeminiService] Rate limited (429), retrying in \(delay) seconds...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        lastError = GeminiError.rateLimited("Rate limited, retrying...")
                        continue
                    } else {
                        print("❌ [GeminiService] Rate limit exceeded after \(maxRetries) attempts")
                        throw GeminiError.rateLimited("API rate limit exceeded. Please wait a moment and try again.")
                    }
                }
                
                // Handle other HTTP errors
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ [GeminiService] HTTP Error \(httpResponse.statusCode): \(errorBody.prefix(200))")
                    throw GeminiError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
                }
                
                print("🤖 [GeminiService] Parsing JSON response...")
                guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ [GeminiService] Failed to parse JSON response")
                    throw GeminiError.invalidResponse
                }
                print("🤖 [GeminiService] JSON parsed successfully, keys: \(jsonResponse.keys.joined(separator: ", "))")
                
                guard let candidates = jsonResponse["candidates"] as? [[String: Any]] else {
                    print("❌ [GeminiService] Missing 'candidates' in response")
                    print("🤖 [GeminiService] Response structure: \(jsonResponse)")
                    throw GeminiError.invalidResponse
                }
                
                print("🤖 [GeminiService] Found \(candidates.count) candidate(s)")
                
                guard let firstCandidate = candidates.first else {
                    print("❌ [GeminiService] No candidates in response")
                    throw GeminiError.invalidResponse
                }
                
                guard let content = firstCandidate["content"] as? [String: Any] else {
                    print("❌ [GeminiService] Missing 'content' in candidate")
                    print("🤖 [GeminiService] Candidate structure: \(firstCandidate.keys.joined(separator: ", "))")
                    throw GeminiError.invalidResponse
                }
                
                guard let parts = content["parts"] as? [[String: Any]] else {
                    print("❌ [GeminiService] Missing 'parts' in content")
                    throw GeminiError.invalidResponse
                }
                
                print("🤖 [GeminiService] Found \(parts.count) part(s)")
                
                guard let firstPart = parts.first else {
                    print("❌ [GeminiService] No parts in content")
                    throw GeminiError.invalidResponse
                }
                
                guard let text = firstPart["text"] as? String else {
                    print("❌ [GeminiService] Missing 'text' in part")
                    print("🤖 [GeminiService] Part keys: \(firstPart.keys.joined(separator: ", "))")
                    throw GeminiError.invalidResponse
                }
                
                print("🤖 [GeminiService] Extracted text from response, length: \(text.count) characters")
                print("🤖 [GeminiService] Text preview: \(text.prefix(200))...")
                
                // Extract JSON from response (may be wrapped in markdown code blocks)
                let jsonString = extractJSON(from: text)
                print("🤖 [GeminiService] Extracted JSON string, length: \(jsonString.count) characters")
                print("🤖 [GeminiService] JSON preview: \(jsonString.prefix(200))...")
                
                guard let jsonData = jsonString.data(using: String.Encoding.utf8) else {
                    print("❌ [GeminiService] Failed to convert JSON string to data")
                    throw GeminiError.invalidResponse
                }
                
                print("🤖 [GeminiService] Decoding JSON to WorkflowPlan...")
                let decoder = JSONDecoder()
                do {
                    let plan = try decoder.decode(WorkflowPlan.self, from: jsonData)
                    print("✅ [GeminiService] Successfully decoded WorkflowPlan")
                    print("✅ [GeminiService] Plan ID: \(plan.planId), Steps: \(plan.steps.count)")
                    return plan
                } catch let decodingError as DecodingError {
                    print("❌ [GeminiService] JSON Decoding Error:")
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("❌ [GeminiService] Type mismatch: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        print("❌ [GeminiService] Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("❌ [GeminiService] Value not found: \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        print("❌ [GeminiService] Context: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("❌ [GeminiService] Key not found: \(key.stringValue) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        print("❌ [GeminiService] Context: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("❌ [GeminiService] Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        print("❌ [GeminiService] Context: \(context.debugDescription)")
                    @unknown default:
                        print("❌ [GeminiService] Unknown decoding error: \(decodingError)")
                    }
                    print("❌ [GeminiService] Full JSON that failed to decode:")
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                    throw GeminiError.invalidResponse
                } catch {
                    print("❌ [GeminiService] Unexpected decoding error: \(error)")
                    print("❌ [GeminiService] Full JSON that failed to decode:")
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                    throw error
                }
                
            } catch {
                lastError = error
                // If it's a rate limit error and we have retries left, continue
                if let geminiError = error as? GeminiError,
                   case .rateLimited = geminiError,
                   attempt < maxRetries - 1 {
                    // This is a rate limit error, continue to retry
                    continue
                } else {
                    // Not a rate limit error, or no retries left, throw immediately
                    throw error
                }
            }
        }
        
        // If we exhausted retries, throw the last error
        throw lastError ?? GeminiError.apiError("Request failed after \(maxRetries) attempts")
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

enum GeminiError: LocalizedError, Equatable {
    case apiError(String)
    case invalidResponse
    case rateLimited(String)
    
    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "Gemini API error: \(message)"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .rateLimited(let message):
            return message
        }
    }
    
    static func == (lhs: GeminiError, rhs: GeminiError) -> Bool {
        switch (lhs, rhs) {
        case (.apiError(let lhsMsg), .apiError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.invalidResponse, .invalidResponse):
            return true
        case (.rateLimited(let lhsMsg), .rateLimited(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

