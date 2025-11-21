//
//  ReportDetailView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Detailed view of a completed workflow report
struct ReportDetailView: View {
    let report: Report
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header section
                    headerSection
                    
                    // Workflow summary
                    summarySection
                    
                    // Captured media
                    if !report.sessionState.capturedMedia.isEmpty {
                        mediaSection
                    }
                    
                    // Annotations grouped by step
                    if !report.sessionState.annotations.isEmpty {
                        annotationsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: exportReport) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.workflowName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                Text(report.completedAt, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(report.completedAt, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
            
            HStack(spacing: 24) {
                SummaryCard(
                    title: "Photos",
                    value: "\(report.sessionState.capturedMedia.count)",
                    icon: "photo"
                )
                
                SummaryCard(
                    title: "Annotations",
                    value: "\(report.sessionState.annotations.count)",
                    icon: "note.text"
                )
                
                if let plan = report.sessionState.workflowPlan {
                    SummaryCard(
                        title: "Steps",
                        value: "\(plan.steps.count)",
                        icon: "list.number"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Captured Media")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(report.sessionState.capturedMedia) { media in
                    MediaThumbnail(media: media)
                }
            }
        }
    }
    
    private var annotationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Annotations")
                .font(.headline)
            
            // Group annotations by step
            let groupedAnnotations = Dictionary(grouping: report.sessionState.annotations) { $0.stepId }
            
            ForEach(Array(groupedAnnotations.keys.sorted()), id: \.self) { stepId in
                if let annotations = groupedAnnotations[stepId] {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Step: \(stepId)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ForEach(annotations) { annotation in
                            AnnotationCard(annotation: annotation)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func exportReport() {
        Task {
            do {
                let url = try await createExportPackage()
                await MainActor.run {
                    exportURL = url
                    showingShareSheet = true
                }
            } catch {
                print("❌ [ReportDetailView] Export failed: \(error)")
            }
        }
    }
    
    private func createExportPackage() async throws -> URL {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Copy media files
        let mediaDir = tempDir.appendingPathComponent("media", isDirectory: true)
        try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        
        for media in report.sessionState.capturedMedia {
            let destination = mediaDir.appendingPathComponent(media.fileURL.lastPathComponent)
            try? fileManager.copyItem(at: media.fileURL, to: destination)
        }
        
        // Create report.json with all report data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let reportData = try encoder.encode(report)
        let reportURL = tempDir.appendingPathComponent("report.json")
        try reportData.write(to: reportURL)
        
        // Create zip file
        let zipURL = fileManager.temporaryDirectory.appendingPathComponent("\(report.workflowName)_\(UUID().uuidString).zip")
        try ZipUtility.createZip(from: tempDir, to: zipURL)
        
        // Clean up temp directory
        try? fileManager.removeItem(at: tempDir)
        
        return zipURL
    }
}

/// Summary card component
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    init(title: String, value: String, icon: String, color: Color = .blue) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

/// Media thumbnail component
struct MediaThumbnail: View {
    let media: CapturedMedia
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 100)
                    .overlay(
                        ProgressView()
                    )
            }
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

/// Annotation card component
struct AnnotationCard: View {
    let annotation: Annotation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: annotationIcon)
                    .foregroundColor(annotationColor)
                    .font(.caption)
                
                Text(annotation.type.rawValue.capitalized)
                    .font(.caption)
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

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

