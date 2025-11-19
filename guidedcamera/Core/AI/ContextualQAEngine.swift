//
//  ContextualQAEngine.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import UIKit
import CoreVideo

/// Generates contextual questions based on captured images and manages Q&A flow
@MainActor
class ContextualQAEngine: ObservableObject {
    static let shared = ContextualQAEngine()
    
    @Published var currentQuestion: String?
    @Published var isGeneratingQuestion = false
    @Published var qaHistory: [QAItem] = []
    
    private let yoloAnalyzer = YOLOAnalyzer.shared
    
    private init() {}
    
    /// Generate contextual questions based on captured image
    func generateQuestions(for image: UIImage, stepId: String, workflowContext: String? = nil) async throws -> [String] {
        print("❓ [ContextualQAEngine] Generating questions for step: \(stepId)")
        isGeneratingQuestion = true
        
        defer {
            isGeneratingQuestion = false
        }
        
        // Analyze image with YOLO to detect objects
        guard let pixelBuffer = imageToPixelBuffer(image) else {
            throw ContextualQAError.imageProcessingFailed
        }
        
        let detectedObjects = yoloAnalyzer.detectObjectsRealTime(pixelBuffer, confidenceThreshold: 0.5)
        let objectLabels = detectedObjects.map { $0.label }.joined(separator: ", ")
        
        print("❓ [ContextualQAEngine] Detected objects: \(objectLabels)")
        
        // Generate questions using LLM
        let contextPrompt = buildContextPrompt(
            detectedObjects: objectLabels,
            stepId: stepId,
            workflowContext: workflowContext
        )
        
        do {
            let questions = try await generateQuestionsWithLLM(prompt: contextPrompt)
            print("✅ [ContextualQAEngine] Generated \(questions.count) questions")
            return questions
        } catch {
            print("❌ [ContextualQAEngine] Failed to generate questions: \(error)")
            throw error
        }
    }
    
    /// Process user's answer and potentially generate follow-up questions
    func processAnswer(_ answer: String, for question: String, stepId: String) async throws -> [String]? {
        print("💬 [ContextualQAEngine] Processing answer for question: \(question)")
        
        // Save Q&A to history
        let qaItem = QAItem(question: question, answer: answer, stepId: stepId, timestamp: Date())
        qaHistory.append(qaItem)
        
        // Generate follow-up questions if needed
        let followUpPrompt = buildFollowUpPrompt(question: question, answer: answer, stepId: stepId)
        
        do {
            let followUpQuestions = try await generateQuestionsWithLLM(prompt: followUpPrompt)
            return followUpQuestions.isEmpty ? nil : followUpQuestions
        } catch {
            print("⚠️ [ContextualQAEngine] Failed to generate follow-up questions: \(error)")
            return nil
        }
    }
    
    /// Get all Q&A items for a specific step
    func getQAForStep(_ stepId: String) -> [QAItem] {
        return qaHistory.filter { $0.stepId == stepId }
    }
    
    /// Clear Q&A history
    func clearHistory() {
        qaHistory.removeAll()
        currentQuestion = nil
    }
    
    // MARK: - Private Methods
    
    private func buildContextPrompt(detectedObjects: String, stepId: String, workflowContext: String?) -> String {
        var prompt = """
        You are an AI assistant helping with a guided camera workflow. Based on the detected objects in a captured photo, generate 2-3 relevant, concise questions that would help gather important contextual information.
        
        Detected objects: \(detectedObjects)
        Current step: \(stepId)
        """
        
        if let context = workflowContext {
            prompt += "\nWorkflow context: \(context)"
        }
        
        prompt += """
        
        Generate questions that:
        1. Are specific to what's visible in the photo
        2. Help gather important details not visible in the image
        3. Are concise and easy to answer verbally
        4. Are relevant to inspection/documentation workflows
        
        Return ONLY a JSON array of question strings, nothing else. Example:
        ["What is the condition of the detected items?", "Are there any visible issues or damage?", "What is the approximate age or maintenance status?"]
        """
        
        return prompt
    }
    
    private func buildFollowUpPrompt(question: String, answer: String, stepId: String) -> String {
        return """
        Based on this Q&A exchange, generate 0-2 follow-up questions if more information would be helpful. If no follow-up is needed, return an empty array.
        
        Question: \(question)
        Answer: \(answer)
        Step: \(stepId)
        
        Return ONLY a JSON array of question strings, or an empty array [] if no follow-up is needed.
        """
    }
    
    private func generateQuestionsWithLLM(prompt: String) async throws -> [String] {
        // Try Apple Intelligence first, fallback to Gemini
        if #available(iOS 18.0, *) {
            if #available(iOS 26.0, *) {
                do {
                    return try await generateWithAppleIntelligence(prompt: prompt)
                } catch {
                    print("⚠️ [ContextualQAEngine] Apple Intelligence failed, falling back to Gemini: \(error)")
                    return try await generateWithGemini(prompt: prompt)
                }
            } else {
                return try await generateWithGemini(prompt: prompt)
            }
        } else {
            return try await generateWithGemini(prompt: prompt)
        }
    }
    
    @available(iOS 26.0, *)
    private func generateWithAppleIntelligence(prompt: String) async throws -> [String] {
        // Use AppleLanguageModelService for question generation
        return try await AppleLanguageModelService.shared.generateText(prompt: prompt)
    }
    
    private func generateWithGemini(prompt: String) async throws -> [String] {
        // Use GeminiService for question generation
        // We need to add a method to GeminiService for general text generation
        // For now, return a simple implementation
        return try await GeminiService.shared.generateText(prompt: prompt)
    }
    
    private func imageToPixelBuffer(_ image: UIImage) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.size.width),
            Int(image.size.height),
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
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let ctx = context else { return nil }
        
        ctx.translateBy(x: 0, y: image.size.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(ctx)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        
        return buffer
    }
}

/// Represents a Q&A item
struct QAItem: Codable, Identifiable {
    let id: UUID
    let question: String
    let answer: String
    let stepId: String
    let timestamp: Date
    
    init(id: UUID = UUID(), question: String, answer: String, stepId: String, timestamp: Date) {
        self.id = id
        self.question = question
        self.answer = answer
        self.stepId = stepId
        self.timestamp = timestamp
    }
}

enum ContextualQAError: LocalizedError {
    case imageProcessingFailed
    case notImplemented
    case questionGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image for question generation"
        case .notImplemented:
            return "Feature not yet implemented"
        case .questionGenerationFailed(let message):
            return "Failed to generate questions: \(message)"
        }
    }
}

