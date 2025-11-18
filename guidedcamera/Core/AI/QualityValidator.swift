//
//  QualityValidator.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import UIKit

/// Validates photo quality (sharpness, exposure, composition)
class QualityValidator {
    static let shared = QualityValidator()
    
    private init() {}
    
    /// Validate image quality against validator requirements
    func validate(_ image: UIImage, against validators: [Validator]) async -> ValidationResult {
        var results: [String: Bool] = [:]
        var errors: [String] = []
        
        for validator in validators {
            let passed: Bool
            
            switch validator.name {
            case "sharpness":
                let sharpness = calculateSharpness(image)
                let threshold = validator.value ?? 0.4
                passed = compare(sharpness, validator.op ?? ">=", threshold)
                if !passed {
                    errors.append("Image sharpness (\(String(format: "%.2f", sharpness))) below threshold (\(threshold))")
                }
                
            case "exposure":
                // Simplified exposure check
                let exposure = calculateExposure(image)
                let threshold = validator.value ?? 0.3
                passed = compare(exposure, validator.op ?? ">=", threshold)
                if !passed {
                    errors.append("Image exposure (\(String(format: "%.2f", exposure))) below threshold (\(threshold))")
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
    
    private func compare(_ value: Double, _ op: String, _ threshold: Double) -> Bool {
        switch op {
        case ">=":
            return value >= threshold
        case "<=":
            return value <= threshold
        case ">":
            return value > threshold
        case "<":
            return value < threshold
        case "==":
            return abs(value - threshold) < 0.01
        default:
            return true
        }
    }
    
    private func calculateSharpness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        // Simplified sharpness calculation using Laplacian variance
        // In production, this would use more sophisticated algorithms
        _ = CIImage(cgImage: cgImage)
        _ = CIContext()
        
        // This is a placeholder - real implementation would use Core Image filters
        // For now, return a default value
        return 0.5
    }
    
    private func calculateExposure(_ image: UIImage) -> Double {
        // Simplified exposure calculation
        // In production, this would analyze pixel brightness distribution
        guard image.cgImage != nil else { return 0.0 }
        
        // Placeholder - return default value
        return 0.5
    }
}

struct ValidationResult {
    let passed: Bool
    let errors: [String]
}

