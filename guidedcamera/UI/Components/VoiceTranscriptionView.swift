//
//  VoiceTranscriptionView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// Compact view for displaying real-time voice transcription
struct VoiceTranscriptionView: View {
    let transcription: String
    
    var body: some View {
        VStack(spacing: 8) {
            // Recording indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .opacity(0.9)
                
                Text("Voice Note")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Transcription text
            Text(transcription)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

