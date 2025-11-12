//
//  CaptureView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

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
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraController: captureManager.camera)
                .ignoresSafeArea()
            
            // Visual overlays
            if let step = session.currentStep {
                VisualOverlayView(
                    overlays: step.ui.overlays,
                    progress: session.progress
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
            
            // Start camera session after a brief delay to ensure view is laid out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("📷 [CaptureView] Starting camera session...")
                captureManager.camera.startSession()
            }
        }
        .onDisappear {
            print("📷 [CaptureView] View disappeared, stopping camera session...")
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
        guard let step = session.currentStep else { return }
        
        isCapturing = true
        validationMessage = nil
        
        let sessionId = session.state.workflowPlan?.planId ?? "session"
        let stepId = step.id
        
        captureManager.capturePhoto(sessionId: sessionId, stepId: stepId) { [weak session] (result: Result<CapturedMedia, Error>) in
            DispatchQueue.main.async {
                isCapturing = false
                
                switch result {
                case .success(let media):
                    session?.addMedia(media)
                    validateCapture(media: media, step: step)
                    
                case .failure(let error):
                    validationMessage = "Capture failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func validateCapture(media: CapturedMedia, step: WorkflowStep) {
        isValidating = true
        
        Task {
            // Load image for validation
            guard let imageData = try? Data(contentsOf: media.fileURL),
                  let image = UIImage(data: imageData) else {
                await MainActor.run {
                    isValidating = false
                    validationMessage = "Failed to load image for validation"
                }
                return
            }
            
            // Run quality validators
            let qualityResult = await QualityValidator.shared.validate(image, against: step.validators)
            
            // Run scene validators
            let sceneResult = await SceneValidator.shared.validate(image, against: step.validators)
            
            await MainActor.run {
                isValidating = false
                
                if qualityResult.passed && sceneResult.passed {
                    validationMessage = "✓ Validation passed"
                    guidanceCoordinator.provideFeedback(success: true)
                    
                    // Move to next step after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        session.nextStep()
                        if let nextStep = session.currentStep {
                            guidanceCoordinator.provideGuidance(for: nextStep)
                        } else {
                            // Session complete
                            session.complete()
                            dismiss()
                        }
                    }
                } else {
                    let errors = qualityResult.errors + sceneResult.errors
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

