//
//  ReviewView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Review captured media and annotations
struct ReviewView: View {
    let session: CaptureSession
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationView {
            List {
                Section("Captured Media") {
                    ForEach(session.state.capturedMedia) { media in
                        MediaRow(media: media)
                    }
                }
                
                Section("Annotations") {
                    ForEach(session.state.annotations) { annotation in
                        AnnotationRow(annotation: annotation)
                    }
                }
                
                Section {
                    Button("Export Session") {
                        exportSession()
                    }
                }
            }
            .navigationTitle("Review")
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private func exportSession() {
        Task {
            do {
                let url = try await createExportPackage()
                await MainActor.run {
                    exportURL = url
                    showingShareSheet = true
                }
            } catch {
                print("Export failed: \(error)")
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
        
        for media in session.state.capturedMedia {
            let destination = mediaDir.appendingPathComponent(media.fileURL.lastPathComponent)
            try fileManager.copyItem(at: media.fileURL, to: destination)
        }
        
        // Create annotations.json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let annotationsData = try encoder.encode(session.state.annotations)
        let annotationsURL = tempDir.appendingPathComponent("annotations.json")
        try annotationsData.write(to: annotationsURL)
        
        // Create zip file
        let zipURL = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        try ZipUtility.createZip(from: tempDir, to: zipURL)
        
        // Clean up temp directory
        try? fileManager.removeItem(at: tempDir)
        
        return zipURL
    }
}

struct MediaRow: View {
    let media: CapturedMedia
    
    var body: some View {
        HStack {
            if media.type == .photo {
                Image(systemName: "photo")
            } else {
                Image(systemName: "video")
            }
            Text(media.stepId)
            Spacer()
            Text(media.capturedAt, style: .time)
        }
    }
}

struct AnnotationRow: View {
    let annotation: Annotation
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(annotation.type.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(annotation.content)
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

