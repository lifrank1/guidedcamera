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
    
    /// Compile YAML workflow to JSON plan using Gemini 2.5 Pro
    func compileWorkflow(_ yamlContent: String) async throws -> WorkflowPlan {
        let url = URL(string: "\(baseURL)/models/gemini-2.0-flash-exp:generateContent?key=\(apiKey)")!
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GeminiError.apiError("HTTP \(response)")
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = jsonResponse?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        // Extract JSON from response (may be wrapped in markdown code blocks)
        let jsonString = extractJSON(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let plan = try decoder.decode(WorkflowPlan.self, from: jsonData)
        
        return plan
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

enum GeminiError: LocalizedError {
    case apiError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "Gemini API error: \(message)"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        }
    }
}

