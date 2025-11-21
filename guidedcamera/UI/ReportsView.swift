//
//  ReportsView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI
import Combine

/// View displaying all completed workflow reports
struct ReportsView: View {
    @State private var reports: [Report] = []
    @State private var selectedReport: Report?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationView {
            Group {
                if reports.isEmpty {
                    emptyStateView
                } else {
                    reportsList
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadReports()
            }
            .refreshable {
                loadReports()
            }
            .onReceive(NotificationCenter.default.publisher(for: .reportSaved)) { _ in
                loadReports()
            }
            .sheet(isPresented: $showingDetail) {
                if let report = selectedReport {
                    ReportDetailView(report: report)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Reports Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete a workflow to generate your first report")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var reportsList: some View {
        List {
            ForEach(reports) { report in
                ReportRow(report: report)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedReport = report
                        showingDetail = true
                    }
            }
            .onDelete(perform: deleteReports)
        }
        .listStyle(PlainListStyle())
    }
    
    private func loadReports() {
        reports = ReportManager.shared.loadAllReports()
    }
    
    private func deleteReports(at offsets: IndexSet) {
        for index in offsets {
            let report = reports[index]
            do {
                try ReportManager.shared.deleteReport(id: report.id)
            } catch {
                print("❌ [ReportsView] Failed to delete report: \(error)")
            }
        }
        loadReports()
    }
}

/// Row view for displaying a report in the list
struct ReportRow: View {
    let report: Report
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail from first captured media
            if let firstMedia = report.sessionState.capturedMedia.first,
               let image = loadThumbnail(from: firstMedia.fileURL) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(report.workflowName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(report.completedAt, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Label("\(report.sessionState.capturedMedia.count)", systemImage: "photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(report.sessionState.annotations.count)", systemImage: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private func loadThumbnail(from url: URL) -> UIImage? {
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            return nil
        }
        return image
    }
}

