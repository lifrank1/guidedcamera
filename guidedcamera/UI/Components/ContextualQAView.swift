//
//  ContextualQAView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// View for displaying and managing contextual Q&A conversations
struct ContextualQAView: View {
    let questions: [String]
    let onAnswer: (String, String) -> Void
    let onDismiss: () -> Void
    
    @State private var currentQuestionIndex = 0
    @State private var answers: [String: String] = [:]
    @State private var isTranscribing = false
    @State private var questionStartTime: Date?
    @State private var answerTimeoutTimer: Timer?
    
    @StateObject private var audioManager = AudioRecordingManager.shared
    @StateObject private var speechService = SpeechRecognitionService.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Minimal header - compact
            HStack {
                Text("\(currentQuestionIndex + 1)/\(questions.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            
            // Current question - compact
            if currentQuestionIndex < questions.count {
                VStack(spacing: 10) {
                    Text(questions[currentQuestionIndex])
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                    
                    // Answer section - minimal design
                    if let answer = answers[questions[currentQuestionIndex]] {
                        // Show transcribed answer
                        Text(answer)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(10)
                            .padding(.horizontal, 12)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        // Auto-recording indicator (very subtle)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .opacity(0.9)
                            
                            Text("Listening...")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.vertical, 8)
                        .transition(.opacity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            // Translucent background with blur effect
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            // Auto-start processing first question
            startQuestionProcessing()
        }
        .onChange(of: currentQuestionIndex) {
            // When question changes, start processing new question
            startQuestionProcessing()
        }
    }
    
    private func startQuestionProcessing() {
        guard currentQuestionIndex < questions.count else {
            // All questions answered, auto-dismiss
            saveAllAnswers()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onDismiss()
            }
            return
        }
        
        let currentQuestion = questions[currentQuestionIndex]
        
        // Skip if already answered
        guard answers[currentQuestion] == nil else {
            // Already answered, auto-advance after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                advanceToNextQuestion()
            }
            return
        }
        
        // Mark question start time for segment extraction
        questionStartTime = Date()
        audioManager.markStepStart("qa_\(currentQuestionIndex)")
        
        // Set timeout for answer (10 seconds max per question)
        answerTimeoutTimer?.invalidate()
        answerTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            Task { @MainActor in
                // Timeout reached, transcribe what we have and advance
                self.transcribeAndAdvance()
            }
        }
        
        // Start checking for answer completion after 2 seconds
        // This allows user to speak naturally
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.monitorAnswerCompletion()
        }
    }
    
    private func monitorAnswerCompletion() {
        // Monitor for answer completion
        // Check every 1.5 seconds if we have transcription
        var checkCount = 0
        let maxChecks = 6 // 6 checks = ~9 seconds total
        
        func check() {
            guard checkCount < maxChecks, currentQuestionIndex < questions.count else {
                // Max checks reached or question changed, transcribe
                transcribeAndAdvance()
                return
            }
            
            let currentQuestion = questions[currentQuestionIndex]
            
            // If already answered, advance
            if answers[currentQuestion] != nil {
                advanceToNextQuestion()
                return
            }
            
            // Check if we have transcription text (from continuous recording)
            // For now, we'll use timeout-based approach
            // In future, could use silence detection from audio levels
            checkCount += 1
            
            // Continue monitoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                check()
            }
        }
        
        check()
    }
    
    private func transcribeAndAdvance() {
        answerTimeoutTimer?.invalidate()
        answerTimeoutTimer = nil
        
        guard currentQuestionIndex < questions.count else { return }
        let currentQuestion = questions[currentQuestionIndex]
        
        // If already answered, just advance
        if answers[currentQuestion] != nil {
            advanceToNextQuestion()
            return
        }
        
        isTranscribing = true
        
        Task {
            // Since we're using continuous recording, we'll transcribe the full recording
            // In a more advanced implementation, we'd extract the segment between
            // questionStartTime and now using audio processing
            
            // Get the continuous recording URL
            guard let audioURL = audioManager.getRecordingURL() else {
                await MainActor.run {
                    // No audio, skip this question
                    isTranscribing = false
                    advanceToNextQuestion()
                }
                return
            }
            
            // For continuous recording, we transcribe the full file
            // In a more advanced implementation, we'd extract the segment between
            // questionStartTime and segmentEndTime
            do {
                let transcription = try await speechService.transcribe(audioFileURL: audioURL)
                await MainActor.run {
                    // Extract relevant portion if we have timestamps
                    // For now, use full transcription (will be refined later)
                    let answerText = transcription.isEmpty ? "[No answer detected]" : transcription
                    
                    if !transcription.isEmpty {
                        answers[currentQuestion] = answerText
                        onAnswer(currentQuestion, answerText)
                    }
                    
                    isTranscribing = false
                    
                    // Brief pause before advancing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        // Mark new question start if there's a next question
                        if self.currentQuestionIndex < self.questions.count - 1 {
                            self.audioManager.markStepStart("qa_\(self.currentQuestionIndex + 1)")
                        }
                        self.advanceToNextQuestion()
                    }
                }
            } catch {
                await MainActor.run {
                    print("⚠️ [ContextualQAView] Transcription failed: \(error)")
                    isTranscribing = false
                    // Skip this question and advance
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.advanceToNextQuestion()
                    }
                }
            }
        }
    }
    
    private func advanceToNextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            // startQuestionProcessing will be called via onChange
        } else {
            // All questions complete
            saveAllAnswers()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onDismiss()
            }
        }
    }
    
    private func saveAllAnswers() {
        // Save all Q&A pairs
        for (question, answer) in answers {
            onAnswer(question, answer)
        }
    }
}


