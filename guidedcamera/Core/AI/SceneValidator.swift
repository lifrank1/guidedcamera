//
//  SceneValidator.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import UIKit

/// Validates scene content against workflow requirements
class SceneValidator {
    static let shared = SceneValidator()
    
    private let visionAnalyzer = VisionAnalyzer.shared
    
    private init() {}
    
    /// Validate scene content against validators
    func validate(_ image: UIImage, against validators: [Validator]) async -> ValidationResult {
        var results: [String: Bool] = [:]
        var errors: [String] = []
        
        // Analyze image first
        let analysisResult = await withCheckedContinuation { continuation in
            visionAnalyzer.analyzeImage(image) { result in
                continuation.resume(returning: result)
            }
        }
        
        guard case .success(let analysis) = analysisResult else {
            return ValidationResult(passed: false, errors: ["Failed to analyze image"])
        }
        
        for validator in validators {
            let passed: Bool
            
            switch validator.name {
            case "contains":
                if let argsDict = validator.args,
                   let labelsAnyOf = extractLabelsAnyOf(from: argsDict) {
                    // Check if any of the required labels are detected
                    let detectedLower = analysis.detectedObjects.map { $0.lowercased() }
                    let requiredLower = labelsAnyOf.map { $0.lowercased() }
                    passed = !Set(detectedLower).isDisjoint(with: Set(requiredLower))
                    
                    if !passed {
                        errors.append("Required objects not found: \(labelsAnyOf.joined(separator: ", "))")
                    }
                } else {
                    passed = true
                }
                
            default:
                // Unknown validator - assume passed
                passed = true
            }
            
            results[validator.name] = passed
        }
        
        let allPassed = results.values.allSatisfy { $0 }
        return ValidationResult(passed: allPassed, errors: errors)
    }
    
    private func extractLabelsAnyOf(from argsDict: [String: AnyCodable]) -> [String]? {
        guard let labelsAnyOfCodable = argsDict["labelsAnyOf"],
              let labelsAnyOf = labelsAnyOfCodable.value as? [String] else {
            return nil
        }
        return labelsAnyOf
    }
}

