//
//  VisionAnalyzer.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import Vision
import UIKit

/// Uses Vision framework for object detection and scene analysis
class VisionAnalyzer {
    static let shared = VisionAnalyzer()
    
    private init() {}
    
    /// Analyze image for objects and scene content
    /// @deprecated: Use YOLOAnalyzer for object detection instead
    @available(*, deprecated, message: "Use YOLOAnalyzer.detectObjects() instead for better accuracy")
    func analyzeImage(_ image: UIImage, completion: @escaping (Result<VisionAnalysis, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(VisionError.invalidImage))
            return
        }
        
        // Use VNRecognizeTextRequest for text detection and VNClassifyImageRequest for scene classification
        // For Phase 1, we'll use a simplified approach with image classification
        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNClassificationObservation] else {
                completion(.success(VisionAnalysis(detectedObjects: [], qualityScore: 0.5)))
                return
            }
            
            // Get top classifications as detected objects
            let objects = observations.prefix(5).compactMap { observation -> String? in
                observation.identifier
            }
            
            // Calculate quality score (simplified - based on confidence of top classification)
            let qualityScore = observations.first?.confidence ?? 0.5
            
            let analysis = VisionAnalysis(
                detectedObjects: Array(objects),
                qualityScore: Double(qualityScore)
            )
            
            completion(.success(analysis))
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Calculate image sharpness
    func calculateSharpness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        // Simplified sharpness calculation using Laplacian variance
        // In production, this would use more sophisticated algorithms
        _ = CIImage(cgImage: cgImage)
        _ = CIContext()
        
        // This is a placeholder - real implementation would use Core Image filters
        // For now, return a default value
        return 0.5
    }
}

struct VisionAnalysis {
    let detectedObjects: [String]
    let qualityScore: Double
}

enum VisionError: LocalizedError {
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image for analysis"
        }
    }
}

