//
//  VoiceAnnotationButton.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// Microphone button for voice annotation recording
struct VoiceAnnotationButton: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.white.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if isTranscribing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(isTranscribing)
    }
}

