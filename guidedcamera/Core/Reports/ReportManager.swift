//
//  ReportManager.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Notification name for when a new report is saved
extension Notification.Name {
    static let reportSaved = Notification.Name("reportSaved")
}

/// Manages persistence and retrieval of completed workflow reports
class ReportManager {
    static let shared = ReportManager()
    
    private let userDefaults = UserDefaults.standard
    private let reportsKey = "completedReports"
    
    private init() {}
    
    /// Save a report to persistent storage
    func saveReport(_ report: Report) throws {
        var reports = loadAllReports()
        reports.append(report)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(reports)
        userDefaults.set(data, forKey: reportsKey)
        
        print("✅ [ReportManager] Saved report: \(report.workflowName) (ID: \(report.id))")
        
        // Post notification that a new report was saved
        NotificationCenter.default.post(name: .reportSaved, object: nil)
    }
    
    /// Load all saved reports, sorted by completion date (newest first)
    func loadAllReports() -> [Report] {
        guard let data = userDefaults.data(forKey: reportsKey) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let reports = try? decoder.decode([Report].self, from: data) else {
            print("⚠️ [ReportManager] Failed to decode reports")
            return []
        }
        
        // Sort by completion date, newest first
        return reports.sorted { $0.completedAt > $1.completedAt }
    }
    
    /// Delete a report by ID
    func deleteReport(id: UUID) throws {
        var reports = loadAllReports()
        reports.removeAll { $0.id == id }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(reports)
        userDefaults.set(data, forKey: reportsKey)
        
        print("✅ [ReportManager] Deleted report with ID: \(id)")
    }
    
    /// Clear all reports
    func clearAllReports() {
        userDefaults.removeObject(forKey: reportsKey)
        print("✅ [ReportManager] Cleared all reports")
    }
}

