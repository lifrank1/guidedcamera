//
//  AnnotationRecordingView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// Overlay view shown during voice annotation recording
struct AnnotationRecordingView: View {
    let duration: TimeInterval
    let transcription: String?
    
    var body: some View {
        VStack(spacing: 12) {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .overlay(
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .scaleEffect(1.2)
                            .opacity(0.6)
                    )
                
                Text("Recording")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            
            // Duration
            Text(formatDuration(duration))
                .foregroundColor(.white)
                .font(.title2)
                .monospacedDigit()
            
            // Transcription preview (if available)
            if let transcription = transcription, !transcription.isEmpty {
                Text(transcription)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.body)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

