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
    @State private var showReview = false
    
    // Voice annotation state
    @StateObject private var audioManager = AudioRecordingManager.shared
    @StateObject private var speechService = SpeechRecognitionService.shared
    @StateObject private var qaEngine = ContextualQAEngine.shared
    @State private var showContextualQA = false
    @State private var contextualQuestions: [String] = []
    @State private var lastCapturedMedia: CapturedMedia?
    
    // Computed property for flash icon
    private var flashIconName: String {
        switch captureManager.camera.flashMode {
        case .off:
            return "bolt.slash"
        case .auto:
            return "bolt.badge.a"
        case .on:
            return "bolt.fill"
        @unknown default:
            return "bolt.slash"
        }
    }
    
    var body: some View {
        Group {
            if showReview {
                // Show review view when session is complete
                ReviewView(session: session) {
                    // When review is dismissed, dismiss the capture view to return to setup
                    dismiss()
                }
            } else {
                // Show camera capture interface
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
                    VStack(spacing: 0) {
                        // Minimal top bar - anchored to top
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(10)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 16)
                            .padding(.top, 8)
                            
                            Spacer()
                            
                            // Camera controls
                            HStack(spacing: 16) {
                                // Flash button
                                Button(action: {
                                    captureManager.camera.toggleFlash()
                                }) {
                                    Image(systemName: flashIconName)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(10)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(Circle())
                                }
                                
                                // Camera flip button
                                Button(action: {
                                    captureManager.camera.switchCamera()
                                }) {
                                    Image(systemName: "camera.rotate")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(10)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(Circle())
                                }
                                
                                // Step counter
                                if session.currentStep != nil {
                                    Text("\(session.state.currentStepIndex + 1)/\(session.state.workflowPlan?.steps.count ?? 0)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.black.opacity(0.4))
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        
                        Spacer()
                        
                        // Middle content - instructions and validation
                        VStack(spacing: 12) {
                            // Instruction text (minimal, elegant)
                            if let step = session.currentStep, !showContextualQA {
                                Text(step.ui.instruction)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.black.opacity(0.65))
                                    .cornerRadius(16)
                                    .padding(.horizontal, 24)
                            }
                            
                            // Validation message (minimal, elegant)
                            if let message = validationMessage {
                                Text(message)
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(14)
                                    .padding(.horizontal, 24)
                            }
                        }
                        
                        Spacer()
                        
                        // Real-time voice transcription display - positioned above buttons
                        if !showContextualQA && !speechService.currentTranscription.isEmpty {
                            VoiceTranscriptionView(transcription: speechService.currentTranscription)
                                .padding(.bottom, 20)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        // Contextual Q&A - positioned above buttons (small, translucent)
                        if showContextualQA && !contextualQuestions.isEmpty {
                            ContextualQAView(
                                questions: contextualQuestions,
                                onAnswer: { question, answer in
                                    saveContextualQA(question: question, answer: answer)
                                },
                                onDismiss: {
                                    showContextualQA = false
                                    contextualQuestions = []
                                    // Continue workflow after Q&A completes
                                    continueAfterQA()
                                }
                            )
                            .padding(.bottom, 20)
                        }
                        
                        // Bottom controls - anchored to bottom
                        HStack(spacing: 50) {
                            // Skip button (subtle)
                            Button(action: skipStep) {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            // Capture button (prominent)
                            Button(action: capture) {
                                Circle()
                                    .fill(isCapturing ? Color.red : Color.white)
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 4)
                                            .frame(width: 84, height: 84)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isCapturing || isValidating)
                            
                            // Retry button (subtle)
                            Button(action: retryStep) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.vertical, 30)
                        .padding(.horizontal, 40)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .background(
                            // Subtle gradient background for better visibility
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.3)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                
                // Minimal recording indicator (very subtle, top-right)
                if audioManager.isRecording {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                                .padding(.trailing, 12)
                                .padding(.top, 8)
                        }
                        Spacer()
                    }
                }
                }
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
            
            // Start continuous audio recording
            startContinuousRecording()
        }
        .onDisappear {
            print("📷 [CaptureView] View disappeared, stopping camera session...")
            if !showReview {
                captureManager.camera.setRealTimeDetectionEnabled(false)
                captureManager.camera.stopSession()
                // Stop continuous recording
                stopContinuousRecording()
            }
        }
        .onChange(of: showReview) { newValue in
            if newValue {
                // Stop camera when showing review
                print("📷 [CaptureView] Stopping camera for review")
                captureManager.camera.setRealTimeDetectionEnabled(false)
                captureManager.camera.stopSession()
                // Save final voice note and stop recording
                saveCurrentVoiceNote()
                stopContinuousRecording()
            }
        }
        .onChange(of: session.state.currentStepIndex) {
            // Save voice note when step changes
            saveCurrentVoiceNote()
            // Mark new step start for audio segmentation
            if let step = session.currentStep {
                audioManager.markStepStart(step.id)
            }
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
                    
                    // Provide initial guidance and mark step start for recording
                    if let step = session.currentStep {
                        guidanceCoordinator.provideGuidance(for: step)
                        // Mark step start for continuous recording
                        if audioManager.isRecording {
                            audioManager.markStepStart(step.id)
                        }
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
                    lastCapturedMedia = media
                    
                    // Save current voice note when photo is captured
                    if let session = session {
                        let transcription = speechService.getCurrentTranscription()
                        if !transcription.isEmpty {
                            let annotation = Annotation(
                                stepId: step.id,
                                type: .voice,
                                content: transcription
                            )
                            session.addAnnotation(annotation)
                            print("✅ [CaptureView] Saved voice note with photo: \(transcription.prefix(50))...")
                        }
                    }
                    
                    print("📸 [CaptureView] Starting validation...")
                    validateCapture(media: media, step: step)
                    
                    // Generate contextual questions after successful capture (optional - can be disabled)
                    // Task {
                    //     await generateContextualQuestions(for: media, step: step)
                    // }
                    
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
                    print("🔍 [CaptureView] Current step before transition: \(step.id)")
                    print("🔍 [CaptureView] Current stepIndex before transition: \(session.state.currentStepIndex)")
                    if let plan = session.state.workflowPlan {
                        print("🔍 [CaptureView] Total steps in plan: \(plan.steps.count)")
                        print("🔍 [CaptureView] Step IDs: \(plan.steps.map { $0.id })")
                    }
                    validationMessage = "✓ Validation passed"
                    guidanceCoordinator.provideFeedback(success: true)
                    
                    // Save current voice note before moving to next step
                    saveCurrentVoiceNote()
                    
                    // If Q&A is showing, wait for it to complete before advancing
                    // Otherwise, move to next step after a brief delay
                    if showContextualQA {
                        // Q&A will call continueAfterQA() when done, which will trigger next step
                        print("⏳ [CaptureView] Waiting for Q&A to complete before advancing")
                    } else {
                        // No Q&A, advance immediately
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.advanceToNextStep()
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
        // Save current voice note before skipping
        saveCurrentVoiceNote()
        
        session.skipStep()
        if let step = session.currentStep {
            guidanceCoordinator.provideGuidance(for: step)
            // Mark new step start for continuous recording
            if audioManager.isRecording {
                audioManager.markStepStart(step.id)
            }
        }
    }
    
    private func retryStep() {
        session.retryStep()
        validationMessage = nil
    }
    
    // MARK: - Continuous Audio Recording
    
    private func startContinuousRecording() {
        Task {
            do {
                // Check permissions
                let micPermission = await PermissionManager.shared.requestMicrophonePermission()
                let speechPermission = await PermissionManager.shared.requestSpeechRecognitionPermission()
                
                guard micPermission && speechPermission else {
                    await MainActor.run {
                        print("⚠️ [CaptureView] Audio permissions not granted, skipping continuous recording")
                    }
                    return
                }
                
                // Start audio recording
                try await audioManager.startRecording()
                
                // Start real-time transcription
                try speechService.startRealTimeTranscription()
                
                await MainActor.run {
                    print("✅ [CaptureView] Continuous audio recording and real-time transcription started")
                    // Mark current step if available
                    if let step = session.currentStep {
                        audioManager.markStepStart(step.id)
                    }
                }
            } catch {
                await MainActor.run {
                    print("⚠️ [CaptureView] Failed to start continuous recording/transcription: \(error.localizedDescription)")
                    // Don't show error to user, recording is optional
                }
            }
        }
    }
    
    private func stopContinuousRecording() {
        // Save current voice note before stopping
        saveCurrentVoiceNote()
        
        // Stop real-time transcription
        speechService.stopRealTimeTranscription()
        
        // Stop audio recording
        audioManager.stopRecording()
        print("✅ [CaptureView] Continuous audio recording and transcription stopped")
    }
    
    /// Save current voice note as annotation
    private func saveCurrentVoiceNote() {
        let transcription = speechService.getCurrentTranscription()
        guard !transcription.isEmpty, let step = session.currentStep else {
            return
        }
        
        let annotation = Annotation(
            stepId: step.id,
            type: .voice,
            content: transcription
        )
        session.addAnnotation(annotation)
        print("✅ [CaptureView] Saved voice note: \(transcription.prefix(50))...")
    }
    
    private func transcribeCurrentSegment() {
        guard let step = session.currentStep,
              let audioURL = audioManager.getRecordingURL(for: step.id) else {
            print("⚠️ [CaptureView] No audio to transcribe for current step")
            return
        }
        
        Task {
            do {
                let transcription = try await speechService.transcribe(audioFileURL: audioURL)
                await MainActor.run {
                    // Save annotation to session
                    let annotation = Annotation(
                        stepId: step.id,
                        type: .voice,
                        content: transcription
                    )
                    session.addAnnotation(annotation)
                    
                    print("✅ [CaptureView] Audio segment transcribed and saved: \(transcription.prefix(50))...")
                }
            } catch {
                await MainActor.run {
                    print("⚠️ [CaptureView] Transcription failed: \(error.localizedDescription)")
                    // Don't show error, transcription is optional
                }
            }
        }
    }
    
    // MARK: - Contextual Q&A
    
    private func generateContextualQuestions(for media: CapturedMedia, step: WorkflowStep) async {
        guard let imageData = try? Data(contentsOf: media.fileURL),
              let image = UIImage(data: imageData) else {
            print("❌ [CaptureView] Failed to load image for Q&A generation")
            return
        }
        
        // Auto-trigger Q&A generation immediately after capture
        do {
            let workflowName = session.state.workflowPlan?.planId ?? "workflow"
            let questions = try await qaEngine.generateQuestions(
                for: image,
                stepId: step.id,
                workflowContext: workflowName
            )
            
            await MainActor.run {
                if !questions.isEmpty {
                    contextualQuestions = questions
                    // Auto-show Q&A overlay with smooth animation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showContextualQA = true
                    }
                    qaEngine.currentQuestion = questions.first
                }
            }
        } catch {
            print("⚠️ [CaptureView] Failed to generate contextual questions: \(error)")
            // Don't show error to user, Q&A is optional - workflow continues
        }
    }
    
    private func saveContextualQA(question: String, answer: String) {
        guard let step = session.currentStep else { return }
        
        let annotation = Annotation(
            stepId: step.id,
            type: .contextualQA,
            content: "Q: \(question)\nA: \(answer)"
        )
        session.addAnnotation(annotation)
        
        print("✅ [CaptureView] Contextual Q&A saved: \(question) -> \(answer)")
    }
    
    private func continueAfterQA() {
        // Called when Q&A completes - advance to next step
        print("✅ [CaptureView] Q&A completed, advancing to next step")
        
        // Brief delay for smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.advanceToNextStep()
        }
    }
    
    private func advanceToNextStep() {
        print("➡️ [CaptureView] Advancing to next step")
        session.nextStep()
        
        // Mark new step start in continuous recording
        if let nextStep = session.currentStep {
            audioManager.markStepStart(nextStep.id)
            guidanceCoordinator.provideGuidance(for: nextStep)
        } else {
            // Session complete
            if !session.isComplete {
                session.complete()
            }
            showReview = true
        }
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

