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
    
    private let yoloAnalyzer = YOLOAnalyzer.shared
    
    private init() {}
    
    /// Validate scene content against validators
    func validate(_ image: UIImage, against validators: [Validator]) async -> ValidationResult {
        var results: [String: Bool] = [:]
        var errors: [String] = []
        
        // Detect objects using YOLO
        let detectedObjects = await yoloAnalyzer.detectObjects(image, confidenceThreshold: 0.5)
        
        // Extract detected labels (normalize class names)
        let detectedLabels = detectedObjects.map { COCOClasses.normalizeClassName($0.label) }
        print("🔍 [SceneValidator] YOLO detected objects: \(detectedLabels)")
        
        for validator in validators {
            let passed: Bool
            
            switch validator.name {
            case "contains":
                if let argsDict = validator.args,
                   let labelsAnyOf = extractLabelsAnyOf(from: argsDict) {
                    // Normalize required labels
                    let requiredNormalized = labelsAnyOf.map { COCOClasses.normalizeClassName($0) }
                    
                    // Check if any of the required labels are detected
                    let detectedLower = detectedLabels.map { $0.lowercased() }
                    let requiredLower = requiredNormalized.map { $0.lowercased() }
                    passed = !Set(detectedLower).isDisjoint(with: Set(requiredLower))
                    
                    if !passed {
                        errors.append("Required objects not found: \(labelsAnyOf.joined(separator: ", "))")
                        print("❌ [SceneValidator] Validation failed. Detected: \(detectedLabels), Required: \(requiredNormalized)")
                    } else {
                        print("✅ [SceneValidator] Validation passed. Found: \(Set(detectedLower).intersection(Set(requiredLower)))")
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

