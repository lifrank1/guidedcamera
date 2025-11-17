//
//  YOLOAnalyzer.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import CoreML
import UIKit
import CoreVideo
import Accelerate

/// Detected object from YOLO inference
struct DetectedObject {
    let label: String
    let confidence: Double
    let boundingBox: CGRect
    let classId: Int
}

/// Uses YOLOv11n Core ML model for object detection
class YOLOAnalyzer {
    static let shared = YOLOAnalyzer()
    
    private var model: MLModel?
    private let modelName = "yolov11n"
    private let inputSize = 640 // YOLO standard input size
    private let confidenceThreshold: Double = 0.5
    private let iouThreshold: Double = 0.45 // Intersection over Union threshold for NMS
    
    private init() {
        loadModel()
    }
    
    /// Load Core ML model from bundle
    private func loadModel() {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") ??
                            Bundle.main.url(forResource: modelName, withExtension: "mlmodel") ??
                            Bundle.main.url(forResource: modelName, withExtension: "mlpackage") else {
            print("⚠️ [YOLOAnalyzer] Model file not found: \(modelName).mlmodelc, \(modelName).mlmodel, or \(modelName).mlpackage")
            print("⚠️ [YOLOAnalyzer] Please add the YOLOv11n Core ML model to the app bundle")
            return
        }
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine // Use Neural Engine for better performance
            model = try MLModel(contentsOf: modelURL, configuration: config)
            print("✅ [YOLOAnalyzer] YOLOv11n model loaded successfully from: \(modelURL.lastPathComponent)")
        } catch {
            print("❌ [YOLOAnalyzer] Failed to load model: \(error)")
        }
    }
    
    /// Detect objects in UIImage (for post-capture validation)
    func detectObjects(_ image: UIImage, confidenceThreshold: Double = 0.5) async -> [DetectedObject] {
        guard model != nil else {
            print("❌ [YOLOAnalyzer] Model not loaded")
            return []
        }
        
        guard let pixelBuffer = imageToPixelBuffer(image, size: CGSize(width: inputSize, height: inputSize)) else {
            print("❌ [YOLOAnalyzer] Failed to convert image to pixel buffer")
            return []
        }
        
        return await performInference(pixelBuffer: pixelBuffer, confidenceThreshold: confidenceThreshold)
    }
    
    /// Detect objects in CVPixelBuffer (for real-time preview)
    func detectObjectsRealTime(_ pixelBuffer: CVPixelBuffer, confidenceThreshold: Double = 0.5) -> [DetectedObject] {
        guard let model = model else {
            return []
        }
        
        // Resize pixel buffer to model input size
        guard let resizedBuffer = resizePixelBuffer(pixelBuffer, width: inputSize, height: inputSize) else {
            return []
        }
        
        // Run inference synchronously for real-time (on background queue)
        return performInferenceSync(pixelBuffer: resizedBuffer, confidenceThreshold: confidenceThreshold)
    }
    
    /// Perform inference asynchronously
    private func performInference(pixelBuffer: CVPixelBuffer, confidenceThreshold: Double) async -> [DetectedObject] {
        guard model != nil else { return [] }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                let results = self.performInferenceSync(pixelBuffer: pixelBuffer, confidenceThreshold: confidenceThreshold)
                continuation.resume(returning: results)
            }
        }
    }
    
    /// Perform inference synchronously
    private func performInferenceSync(pixelBuffer: CVPixelBuffer, confidenceThreshold: Double) -> [DetectedObject] {
        guard let model = model else { return [] }
        
        do {
            // Create input
            let input = MLFeatureValue(pixelBuffer: pixelBuffer)
            let provider = try MLDictionaryFeatureProvider(dictionary: ["image": input])
            
            // Run prediction
            let prediction = try model.prediction(from: provider)
            
            // Debug: Print all available output feature names
            print("🔍 [YOLOAnalyzer] Available output features: \(prediction.featureNames)")
            
            // Try different possible output names (YOLOv11 might use different names)
            var output: MLMultiArray?
            var outputName: String?
            
            // Common output names for YOLO models
            let possibleOutputNames = ["output", "output0", "output_0", "var_1234", "detections", "boxes"]
            
            for name in possibleOutputNames {
                if let featureValue = prediction.featureValue(for: name)?.multiArrayValue {
                    output = featureValue
                    outputName = name
                    print("✅ [YOLOAnalyzer] Found output at feature: '\(name)'")
                    break
                }
            }
            
            // If not found, try the first feature
            if output == nil, let firstFeatureName = prediction.featureNames.first {
                if let featureValue = prediction.featureValue(for: firstFeatureName)?.multiArrayValue {
                    output = featureValue
                    outputName = firstFeatureName
                    print("✅ [YOLOAnalyzer] Using first available feature: '\(firstFeatureName)'")
                }
            }
            
            guard let output = output else {
                print("❌ [YOLOAnalyzer] Invalid output format - no multiArray found")
                print("❌ [YOLOAnalyzer] Available features: \(prediction.featureNames)")
                // Print details of each feature
                for name in prediction.featureNames {
                    if let feature = prediction.featureValue(for: name) {
                        print("🔍 [YOLOAnalyzer] Feature '\(name)': type = \(type(of: feature))")
                    }
                }
                return []
            }
            
            print("🔍 [YOLOAnalyzer] Output shape: \(output.shape), count: \(output.count)")
            
            // Parse YOLO output
            let detections = parseYOLOOutput(output, confidenceThreshold: confidenceThreshold)
            
            // Apply Non-Maximum Suppression (NMS)
            let filteredDetections = applyNMS(detections, iouThreshold: iouThreshold)
            
            return filteredDetections
            
        } catch {
            print("❌ [YOLOAnalyzer] Inference failed: \(error)")
            return []
        }
    }
    
    /// Parse YOLO model output
    private func parseYOLOOutput(_ output: MLMultiArray, confidenceThreshold: Double) -> [DetectedObject] {
        var detections: [DetectedObject] = []
        
        let shape = output.shape
        print("🔍 [YOLOAnalyzer] Parsing output with shape: \(shape.map { $0.intValue })")
        
        // YOLOv11 might have different output formats:
        // Format 1: [1, num_detections, 85] - batch, detections, (bbox + conf + classes)
        // Format 2: [num_detections, 85] - detections, (bbox + conf + classes)
        // Format 3: [1, 84, 8400] - batch, (bbox + conf + classes), grid cells (YOLOv8/v11 format)
        // Format 4: [num_detections, 6] - detections, (x, y, w, h, conf, class_id) - post-processed format
        
        let shapeArray = shape.map { $0.intValue }
        var numDetections: Int = 0
        var elementsPerDetection: Int = 0
        var isPostProcessed = false
        
        if shape.count == 3 {
            // Format: [batch, num_detections, features] or [batch, features, grid]
            let batch = shapeArray[0]
            let second = shapeArray[1]
            let third = shapeArray[2]
            
            if second == 6 {
                // Post-processed: [1, num_detections, 6] where 6 = (x, y, w, h, conf, class_id)
                numDetections = batch * second
                elementsPerDetection = 6
                isPostProcessed = true
                print("🔍 [YOLOAnalyzer] Detected post-processed format: [\(batch), \(second), \(third)]")
            } else if third == 85 || third == 84 {
                // Standard: [1, num_detections, 85]
                numDetections = second
                elementsPerDetection = third
                print("🔍 [YOLOAnalyzer] Detected standard format: [\(batch), \(second), \(third)]")
            } else {
                // Might be grid format: [1, 84, 8400] - need to decode
                print("🔍 [YOLOAnalyzer] Detected grid format: [\(batch), \(second), \(third)] - attempting grid decoding")
                return parseGridFormat(output, confidenceThreshold: confidenceThreshold)
            }
        } else if shape.count == 2 {
            // Format: [num_detections, features]
            if shapeArray[1] == 6 {
                // Post-processed: [num_detections, 6]
                numDetections = shapeArray[0]
                elementsPerDetection = 6
                isPostProcessed = true
                print("🔍 [YOLOAnalyzer] Detected post-processed format: [\(shapeArray[0]), \(shapeArray[1])]")
            } else {
                // Standard: [num_detections, 85]
                numDetections = shapeArray[0]
                elementsPerDetection = shapeArray[1]
                print("🔍 [YOLOAnalyzer] Detected standard format: [\(shapeArray[0]), \(shapeArray[1])]")
            }
        } else {
            print("❌ [YOLOAnalyzer] Unexpected output shape: \(shapeArray)")
            return []
        }
        
        print("🔍 [YOLOAnalyzer] Parsing \(numDetections) detections with \(elementsPerDetection) elements each")
        
        // Parse based on format
        if isPostProcessed {
            // Post-processed format: [x, y, w, h, confidence, class_id]
            for i in 0..<numDetections {
                let baseIndex = i * elementsPerDetection
                
                let x = output[baseIndex + 0].doubleValue
                let y = output[baseIndex + 1].doubleValue
                let w = output[baseIndex + 2].doubleValue
                let h = output[baseIndex + 3].doubleValue
                let confidence = output[baseIndex + 4].doubleValue
                let classId = Int(output[baseIndex + 5].doubleValue)
                
                if confidence >= confidenceThreshold {
                    let rect = CGRect(x: x, y: y, width: w, height: h)
                    let className = COCOClasses.getClassName(for: classId) ?? "unknown"
                    
                    let detection = DetectedObject(
                        label: className,
                        confidence: confidence,
                        boundingBox: rect,
                        classId: classId
                    )
                    
                    detections.append(detection)
                }
            }
        } else {
            // Standard format: [bbox(4) + objectness(1) + classes(80)]
            for i in 0..<numDetections {
                let baseIndex = i * elementsPerDetection
                
                // Extract bounding box (normalized coordinates: center_x, center_y, width, height)
                let centerX = output[baseIndex + 0].doubleValue
                let centerY = output[baseIndex + 1].doubleValue
                let width = output[baseIndex + 2].doubleValue
                let height = output[baseIndex + 3].doubleValue
                let objectness = output[baseIndex + 4].doubleValue
                
                // Find class with highest score
                var maxScore = 0.0
                var bestClassId = 0
                
                let numClasses = elementsPerDetection - 5
                for classId in 0..<min(numClasses, 80) {
                    let score = output[baseIndex + 5 + classId].doubleValue
                    if score > maxScore {
                        maxScore = score
                        bestClassId = classId
                    }
                }
                
                // Calculate final confidence
                let confidence = objectness * maxScore
                
                if confidence >= confidenceThreshold {
                    // Convert normalized coordinates to CGRect
                    let x = (centerX - width / 2) * Double(inputSize)
                    let y = (centerY - height / 2) * Double(inputSize)
                    let rect = CGRect(x: x, y: y, width: width * Double(inputSize), height: height * Double(inputSize))
                    
                    // Get class name
                    let className = COCOClasses.getClassName(for: bestClassId) ?? "unknown"
                    
                    let detection = DetectedObject(
                        label: className,
                        confidence: confidence,
                        boundingBox: rect,
                        classId: bestClassId
                    )
                    
                    detections.append(detection)
                }
            }
        }
        
        print("✅ [YOLOAnalyzer] Parsed \(detections.count) detections above threshold")
        return detections
    }
    
    /// Parse grid-based YOLO output format (e.g., [1, 84, 8400])
    private func parseGridFormat(_ output: MLMultiArray, confidenceThreshold: Double) -> [DetectedObject] {
        // Grid format: [batch, features, grid_cells]
        // For YOLOv11: [1, 84, 8400]
        // 84 = 4 (bbox: x, y, w, h) + 80 (class scores) - no separate objectness
        // 8400 = 80*80 + 40*40 + 20*20 = 6400 + 1600 + 400 (3 detection scales)
        
        print("🔍 [YOLOAnalyzer] Parsing grid format [1, 84, 8400]")
        
        let shape = output.shape.map { $0.intValue }
        guard shape.count == 3, shape[0] == 1, shape[1] == 84, shape[2] == 8400 else {
            print("❌ [YOLOAnalyzer] Unexpected grid format shape: \(shape)")
            return []
        }
        
        var detections: [DetectedObject] = []
        
        // Grid scales: [80x80, 40x40, 20x20] = [6400, 1600, 400] cells
        let gridSizes = [80, 40, 20]
        let gridOffsets = [0, 6400, 8000] // Cumulative offsets
        
        // Process each scale
        // MLMultiArray with shape [1, 84, 8400] is indexed as: output[feature * 8400 + cell]
        for scaleIndex in 0..<3 {
            let gridSize = gridSizes[scaleIndex]
            let offset = gridOffsets[scaleIndex]
            let cellsInScale = gridSize * gridSize
            
            // Calculate stride for this scale (input size / grid size)
            let stride = Double(inputSize) / Double(gridSize)
            
            // Process each cell in this scale
            for cellIndex in 0..<cellsInScale {
                let globalCellIndex = offset + cellIndex
                
                // For shape [1, 84, 8400], access is: output[feature * 8400 + cell]
                // Feature 0 (centerX): output[0 * 8400 + globalCellIndex]
                // Feature 1 (centerY): output[1 * 8400 + globalCellIndex]
                // Feature 2 (width): output[2 * 8400 + globalCellIndex]
                // Feature 3 (height): output[3 * 8400 + globalCellIndex]
                // Feature 4+ (classes): output[(4+classId) * 8400 + globalCellIndex]
                
                let centerX = output[0 * 8400 + globalCellIndex].doubleValue
                let centerY = output[1 * 8400 + globalCellIndex].doubleValue
                let width = output[2 * 8400 + globalCellIndex].doubleValue
                let height = output[3 * 8400 + globalCellIndex].doubleValue
                
                // Find class with highest score
                var maxScore = 0.0
                var bestClassId = 0
                
                for classId in 0..<80 {
                    let featureIndex = 4 + classId
                    let score = output[featureIndex * 8400 + globalCellIndex].doubleValue
                    if score > maxScore {
                        maxScore = score
                        bestClassId = classId
                    }
                }
                
                // In YOLOv11, maxScore is the confidence (no separate objectness)
                let confidence = maxScore
                
                if confidence >= confidenceThreshold {
                    // Convert grid cell coordinates to image coordinates
                    let gridX = cellIndex % gridSize
                    let gridY = cellIndex / gridSize
                    
                    // Calculate absolute center position
                    // centerX and centerY are offsets from grid cell center (normalized -0.5 to 0.5)
                    let absCenterX = (Double(gridX) + 0.5 + centerX) * stride
                    let absCenterY = (Double(gridY) + 0.5 + centerY) * stride
                    let absWidth = width * Double(inputSize)
                    let absHeight = height * Double(inputSize)
                    
                    // Convert to CGRect (top-left corner)
                    let x = absCenterX - absWidth / 2.0
                    let y = absCenterY - absHeight / 2.0
                    let rect = CGRect(x: x, y: y, width: absWidth, height: absHeight)
                    
                    // Get class name
                    let className = COCOClasses.getClassName(for: bestClassId) ?? "unknown"
                    
                    let detection = DetectedObject(
                        label: className,
                        confidence: confidence,
                        boundingBox: rect,
                        classId: bestClassId
                    )
                    
                    detections.append(detection)
                }
            }
        }
        
        print("✅ [YOLOAnalyzer] Grid parsing found \(detections.count) detections above threshold")
        return detections
    }
    
    /// Apply Non-Maximum Suppression to remove overlapping detections
    private func applyNMS(_ detections: [DetectedObject], iouThreshold: Double) -> [DetectedObject] {
        // Sort by confidence (highest first)
        let sorted = detections.sorted { $0.confidence > $1.confidence }
        var selected: [DetectedObject] = []
        var suppressed = Set<Int>()
        
        for i in 0..<sorted.count {
            if suppressed.contains(i) { continue }
            
            selected.append(sorted[i])
            
            // Suppress overlapping detections
            for j in (i + 1)..<sorted.count {
                if suppressed.contains(j) { continue }
                
                let iou = calculateIOU(sorted[i].boundingBox, sorted[j].boundingBox)
                if iou > iouThreshold {
                    suppressed.insert(j)
                }
            }
        }
        
        return selected
    }
    
    /// Calculate Intersection over Union (IOU) between two rectangles
    private func calculateIOU(_ box1: CGRect, _ box2: CGRect) -> Double {
        let intersection = box1.intersection(box2)
        let union = box1.union(box2)
        
        if union.area == 0 {
            return 0.0
        }
        
        return Double(intersection.area / union.area)
    }
    
    /// Convert UIImage to CVPixelBuffer
    private func imageToPixelBuffer(_ image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let ctx = context else { return nil }
        
        ctx.interpolationQuality = .high
        ctx.draw(image.cgImage!, in: CGRect(origin: .zero, size: size))
        
        return buffer
    }
    
    /// Resize CVPixelBuffer to target size
    private func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var resizedBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &resizedBuffer
        )
        
        guard status == kCVReturnSuccess, let output = resizedBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(output, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(output, [])
        }
        
        let inputBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let outputBaseAddress = CVPixelBufferGetBaseAddress(output)
        
        let inputWidth = CVPixelBufferGetWidth(pixelBuffer)
        let inputHeight = CVPixelBufferGetHeight(pixelBuffer)
        let inputBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(output)
        
        var inputBuffer = vImage_Buffer(
            data: inputBaseAddress,
            height: vImagePixelCount(inputHeight),
            width: vImagePixelCount(inputWidth),
            rowBytes: inputBytesPerRow
        )
        
        var outputBuffer = vImage_Buffer(
            data: outputBaseAddress,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: outputBytesPerRow
        )
        
        let error = vImageScale_ARGB8888(&inputBuffer, &outputBuffer, nil, vImage_Flags(0))
        
        guard error == kvImageNoError else {
            return nil
        }
        
        return output
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    var area: CGFloat {
        return width * height
    }
}

