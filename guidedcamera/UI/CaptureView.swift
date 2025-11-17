//
//  CaptureView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI
import AVFoundation

/// Full-screen camera interface with minimal UI
struct CaptureView: View {
    let workflowName: String
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var session = CaptureSession()
    @StateObject private var captureManager = CaptureManager.shared
    private let guidanceCoordinator = GuidanceCoordinator.shared
    
    @State private var isCapturing = false
    @State private var isValidating = false
    @State private var validationMessage: String?
    @State private var detectedObjects: [DetectedObject] = []
    @State private var isRealTimeDetectionEnabled = true
    @State private var detectionDelegate: RealTimeDetectionDelegate?
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraController: captureManager.camera)
                .ignoresSafeArea()
            
            // Visual overlays
            if let step = session.currentStep {
                VisualOverlayView(
                    overlays: step.ui.overlays,
                    progress: session.progress,
                    detectedObjects: isRealTimeDetectionEnabled ? detectedObjects : nil
                )
            }
            
            // UI overlay
            VStack {
                // Top bar
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                    
                    if session.currentStep != nil {
                        Text("Step \(session.state.currentStepIndex + 1) of \(session.state.workflowPlan?.steps.count ?? 0)")
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .background(Color.black.opacity(0.3))
                
                Spacer()
                
                // Instruction text
                if let step = session.currentStep {
                    Text(step.ui.instruction)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                        .padding()
                }
                
                // Validation message
                if let message = validationMessage {
                    Text(message)
                        .foregroundColor(.yellow)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                        .padding()
                }
                
                // Bottom controls
                HStack(spacing: 40) {
                    // Skip button
                    Button(action: skipStep) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    // Capture button
                    Button(action: capture) {
                        Circle()
                            .fill(isCapturing ? Color.red : Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                            )
                    }
                    .disabled(isCapturing || isValidating)
                    
                    // Retry button
                    Button(action: retryStep) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            print("📷 [CaptureView] View appeared, setting up session...")
            setupSession()
            
            // Set up real-time detection delegate
            detectionDelegate = RealTimeDetectionDelegate { objects in
                DispatchQueue.main.async {
                    detectedObjects = objects
                }
            }
            captureManager.camera.videoDataDelegate = detectionDelegate
            captureManager.camera.setRealTimeDetectionEnabled(isRealTimeDetectionEnabled)
            
            // Start camera session after a brief delay to ensure view is laid out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("📷 [CaptureView] Starting camera session...")
                captureManager.camera.startSession()
            }
        }
        .onDisappear {
            print("📷 [CaptureView] View disappeared, stopping camera session...")
            captureManager.camera.setRealTimeDetectionEnabled(false)
            captureManager.camera.stopSession()
        }
    }
    
    private func setupSession() {
        Task {
            do {
                let sessionManager = SessionManager.shared
                let newSession = try await sessionManager.startSession(withBundledWorkflow: workflowName)
                
                await MainActor.run {
                    // Copy state to our session
                    session.state = newSession.state
                    captureManager.camera.startSession()
                    
                    // Provide initial guidance
                    if let step = session.currentStep {
                        guidanceCoordinator.provideGuidance(for: step)
                    }
                }
            } catch {
                await MainActor.run {
                    validationMessage = "Failed to load workflow: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func capture() {
        print("📸 [CaptureView] Capture button tapped")
        guard let step = session.currentStep else {
            print("❌ [CaptureView] No current step")
            return
        }
        
        print("📸 [CaptureView] Starting capture for step: \(step.id)")
        isCapturing = true
        validationMessage = nil
        
        let sessionId = session.state.workflowPlan?.planId ?? "session"
        let stepId = step.id
        
        print("📸 [CaptureView] Calling captureManager.capturePhoto...")
        captureManager.capturePhoto(sessionId: sessionId, stepId: stepId) { [weak session] (result: Result<CapturedMedia, Error>) in
            print("📸 [CaptureView] Capture completion called")
            DispatchQueue.main.async {
                isCapturing = false
                
                switch result {
                case .success(let media):
                    print("✅ [CaptureView] Photo captured successfully: \(media.fileURL.path)")
                    session?.addMedia(media)
                    print("📸 [CaptureView] Starting validation...")
                    validateCapture(media: media, step: step)
                    
                case .failure(let error):
                    print("❌ [CaptureView] Capture failed: \(error)")
                    validationMessage = "Capture failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func validateCapture(media: CapturedMedia, step: WorkflowStep) {
        print("🔍 [CaptureView] Starting validation for captured media")
        isValidating = true
        
        Task {
            // Load image for validation
            print("🔍 [CaptureView] Loading image from: \(media.fileURL.path)")
            guard let imageData = try? Data(contentsOf: media.fileURL) else {
                print("❌ [CaptureView] Failed to load image data")
                await MainActor.run {
                    isValidating = false
                    validationMessage = "Failed to load image for validation"
                }
                return
            }
            
            guard let image = UIImage(data: imageData) else {
                print("❌ [CaptureView] Failed to create UIImage from data")
                await MainActor.run {
                    isValidating = false
                    validationMessage = "Failed to load image for validation"
                }
                return
            }
            
            print("✅ [CaptureView] Image loaded, size: \(image.size)")
            print("🔍 [CaptureView] Running validators: \(step.validators.count) validators")
            
            // Run quality validators
            let qualityResult = await QualityValidator.shared.validate(image, against: step.validators)
            print("🔍 [CaptureView] Quality validation result: \(qualityResult.passed)")
            
            // Run scene validators
            let sceneResult = await SceneValidator.shared.validate(image, against: step.validators)
            print("🔍 [CaptureView] Scene validation result: \(sceneResult.passed)")
            
            await MainActor.run {
                isValidating = false
                
                if qualityResult.passed && sceneResult.passed {
                    print("✅ [CaptureView] All validations passed, moving to next step")
                    validationMessage = "✓ Validation passed"
                    guidanceCoordinator.provideFeedback(success: true)
                    
                    // Move to next step after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        print("➡️ [CaptureView] Transitioning to next step")
                        session.nextStep()
                        if let nextStep = session.currentStep {
                            print("✅ [CaptureView] Next step: \(nextStep.id)")
                            guidanceCoordinator.provideGuidance(for: nextStep)
                        } else {
                            print("✅ [CaptureView] Session complete!")
                            session.complete()
                            dismiss()
                        }
                    }
                } else {
                    let errors = qualityResult.errors + sceneResult.errors
                    print("❌ [CaptureView] Validation failed: \(errors)")
                    validationMessage = errors.joined(separator: ", ")
                    guidanceCoordinator.provideFeedback(success: false, errors: errors)
                }
            }
        }
    }
    
    private func skipStep() {
        session.skipStep()
        if let step = session.currentStep {
            guidanceCoordinator.provideGuidance(for: step)
        }
    }
    
    private func retryStep() {
        session.retryStep()
        validationMessage = nil
    }
}

/// Delegate for real-time object detection from camera frames
private class RealTimeDetectionDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let onDetection: ([DetectedObject]) -> Void
    private let yoloAnalyzer = YOLOAnalyzer.shared
    
    init(onDetection: @escaping ([DetectedObject]) -> Void) {
        self.onDetection = onDetection
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Run YOLO detection on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Use lower confidence threshold for real-time (more detections)
            let objects = self.yoloAnalyzer.detectObjectsRealTime(pixelBuffer, confidenceThreshold: 0.4)
            
            // Update on main queue
            DispatchQueue.main.async {
                self.onDetection(objects)
            }
        }
    }
}

