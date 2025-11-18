//
//  WorkflowLoader.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Handles loading workflows from local bundle or remote URLs
class WorkflowLoader {
    static let shared = WorkflowLoader()
    
    private let cache = WorkflowCache.shared
    
    private init() {}
    
    /// Load a bundled workflow by name
    func loadBundledWorkflow(_ name: String) throws -> String {
        print("📋 [WorkflowLoader] Loading workflow: \(name)")
        
        // Try multiple methods to find the workflow file
        
        // Method 1: Try with subdirectory
        print("📋 [WorkflowLoader] Method 1: Trying Bundle.main.url with subdirectory 'Workflows'")
        if let url = Bundle.main.url(forResource: name, withExtension: "yaml", subdirectory: "Workflows") {
            print("✅ [WorkflowLoader] Found workflow at: \(url.path)")
            let content = try String(contentsOf: url, encoding: .utf8)
            print("✅ [WorkflowLoader] Loaded \(content.count) characters from workflow file")
            return content
        } else {
            print("❌ [WorkflowLoader] Method 1 failed: File not found in bundle with subdirectory")
        }
        
        // Method 2: Try without subdirectory
        print("📋 [WorkflowLoader] Method 2: Trying Bundle.main.url without subdirectory")
        if let url = Bundle.main.url(forResource: name, withExtension: "yaml") {
            print("✅ [WorkflowLoader] Found workflow at: \(url.path)")
            let content = try String(contentsOf: url, encoding: .utf8)
            print("✅ [WorkflowLoader] Loaded \(content.count) characters from workflow file")
            return content
        } else {
            print("❌ [WorkflowLoader] Method 2 failed: File not found in bundle")
        }
        
        // Method 3: Try resourceURL path
        print("📋 [WorkflowLoader] Method 3: Trying resourceURL path")
        if let resourceURL = Bundle.main.resourceURL {
            let url = resourceURL.appendingPathComponent("Workflows").appendingPathComponent("\(name).yaml")
            print("📋 [WorkflowLoader] Checking path: \(url.path)")
            if FileManager.default.fileExists(atPath: url.path) {
                print("✅ [WorkflowLoader] Found workflow at: \(url.path)")
                let content = try String(contentsOf: url, encoding: .utf8)
                print("✅ [WorkflowLoader] Loaded \(content.count) characters from workflow file")
                return content
            } else {
                print("❌ [WorkflowLoader] Method 3 failed: File does not exist at path")
            }
        } else {
            print("❌ [WorkflowLoader] Method 3 failed: resourceURL is nil")
        }
        
        // Method 4: Fallback - try to load from source directory (for development)
        print("📋 [WorkflowLoader] Method 4: Trying fallback source directory")
        let sourcePath = "/Users/frankli/Projects/guidedcamera/guidedcamera/Resources/Workflows/\(name).yaml"
        print("📋 [WorkflowLoader] Checking fallback path: \(sourcePath)")
        if FileManager.default.fileExists(atPath: sourcePath) {
            print("✅ [WorkflowLoader] Found workflow at fallback path: \(sourcePath)")
            let content = try String(contentsOf: URL(fileURLWithPath: sourcePath), encoding: .utf8)
            print("✅ [WorkflowLoader] Loaded \(content.count) characters from workflow file")
            return content
        } else {
            print("❌ [WorkflowLoader] Method 4 failed: File does not exist at fallback path")
        }
        
        print("❌ [WorkflowLoader] All methods failed. Workflow '\(name)' not found.")
        throw WorkflowError.workflowNotFound(name)
    }
    
    /// Fetch a workflow from a remote URL
    func fetchRemoteWorkflow(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw WorkflowError.invalidURL(urlString)
        }
        
        // Validate HTTPS
        guard url.scheme == "https" else {
            throw WorkflowError.insecureURL
        }
        
        // Check cache first
        if let cached = cache.getCachedYAML(for: url) {
            return cached
        }
        
        // Fetch from network
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WorkflowError.networkError
        }
        
        guard let yamlContent = String(data: data, encoding: .utf8) else {
            throw WorkflowError.invalidEncoding
        }
        
        // Cache the fetched YAML
        try cache.cacheYAML(yamlContent, for: url)
        
        return yamlContent
    }
    
    /// List available bundled workflows
    func listBundledWorkflows() -> [String] {
        // Try multiple methods to find workflows
        
        // Method 1: Try Bundle.main.url with subdirectory
        if let workflowsURL = Bundle.main.resourceURL?.appendingPathComponent("Workflows", isDirectory: true),
           let files = try? FileManager.default.contentsOfDirectory(at: workflowsURL, includingPropertiesForKeys: nil) {
            let workflows = files
                .filter { $0.pathExtension == "yaml" }
                .map { $0.deletingPathExtension().lastPathComponent }
            if !workflows.isEmpty {
                print("Found \(workflows.count) workflows via resourceURL: \(workflows)")
                return workflows
            }
        }
        
        // Method 2: Try Bundle.main.url(forResource:withExtension:subdirectory:)
        let knownWorkflows = ["home_inspection", "vehicle_accident", "contractor_daily", "test_selfie_hand", "test_keyboard_laptop"]
        var foundWorkflows: [String] = []
        
        for workflow in knownWorkflows {
            if Bundle.main.url(forResource: workflow, withExtension: "yaml", subdirectory: "Workflows") != nil {
                foundWorkflows.append(workflow)
            }
        }
        
        if !foundWorkflows.isEmpty {
            print("Found \(foundWorkflows.count) workflows via Bundle API: \(foundWorkflows)")
            return foundWorkflows
        }
        
        // Method 3: Fallback - return known workflows if files exist in source
        // This is a temporary fallback for development
        print("Warning: Could not find workflows in bundle, using fallback list")
        return knownWorkflows
    }
}

enum WorkflowError: LocalizedError {
    case workflowNotFound(String)
    case invalidURL(String)
    case insecureURL
    case networkError
    case invalidEncoding
    
    var errorDescription: String? {
        switch self {
        case .workflowNotFound(let name):
            return "Workflow '\(name)' not found in bundle"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .insecureURL:
            return "Only HTTPS URLs are allowed for security"
        case .networkError:
            return "Failed to fetch workflow from network"
        case .invalidEncoding:
            return "Failed to decode workflow content"
        }
    }
}

