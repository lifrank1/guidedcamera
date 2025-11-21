//
//  ReviewView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// Review captured media and annotations
struct ReviewView: View {
    let session: CaptureSession
    let onDismiss: (() -> Void)?
    
    init(session: CaptureSession, onDismiss: (() -> Void)? = nil) {
        self.session = session
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success header
                    successHeader
                    
                    // Summary cards
                    summarySection
                    
                    // Captured media grid
                    if !session.state.capturedMedia.isEmpty {
                        mediaSection
                    }
                    
                    // Annotations
                    if !session.state.annotations.isEmpty {
                        annotationsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Workflow Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss?()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var successHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("All Steps Completed")
                .font(.title2)
                .fontWeight(.bold)
            
            if let workflowName = session.state.workflowPlan?.planId {
                Text(workflowName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var summarySection: some View {
        HStack(spacing: 16) {
            ReviewSummaryCard(
                title: "Photos",
                value: "\(session.state.capturedMedia.count)",
                icon: "photo.fill",
                color: .blue
            )
            
            ReviewSummaryCard(
                title: "Annotations",
                value: "\(session.state.annotations.count)",
                icon: "note.text",
                color: .purple
            )
            
            if let plan = session.state.workflowPlan {
                ReviewSummaryCard(
                    title: "Steps",
                    value: "\(plan.steps.count)",
                    icon: "list.number",
                    color: .orange
                )
            }
        }
    }
    
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Captured Media")
                .font(.headline)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(session.state.capturedMedia) { media in
                    MediaThumbnailCard(media: media)
                }
            }
        }
    }
    
    private var annotationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Annotations")
                .font(.headline)
                .padding(.horizontal, 4)
            
            // Group annotations by step
            let groupedAnnotations = Dictionary(grouping: session.state.annotations) { $0.stepId }
            
            ForEach(Array(groupedAnnotations.keys.sorted()), id: \.self) { stepId in
                if let annotations = groupedAnnotations[stepId] {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Step: \(stepId)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ForEach(annotations) { annotation in
                            ReviewAnnotationCard(annotation: annotation)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
}

/// Summary card component for ReviewView
struct ReviewSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// Media thumbnail card component
struct MediaThumbnailCard: View {
    let media: CapturedMedia
    @State private var image: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 120)
                        .overlay(
                            ProgressView()
                        )
                }
            }
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(media.stepId)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(media.capturedAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let imageData = try? Data(contentsOf: media.fileURL),
              let loadedImage = UIImage(data: imageData) else {
            return
        }
        image = loadedImage
    }
}

/// Annotation card component for ReviewView
struct ReviewAnnotationCard: View {
    let annotation: Annotation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: annotationIcon)
                .foregroundColor(annotationColor)
                .font(.body)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(annotation.type.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(annotation.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(annotation.content)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var annotationIcon: String {
        switch annotation.type {
        case .voice:
            return "mic.fill"
        case .text:
            return "note.text"
        case .contextualQA:
            return "questionmark.circle.fill"
        }
    }
    
    private var annotationColor: Color {
        switch annotation.type {
        case .voice:
            return .blue
        case .text:
            return .gray
        case .contextualQA:
            return .green
        }
    }
}

