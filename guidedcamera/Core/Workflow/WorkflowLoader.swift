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
        guard let url = Bundle.main.url(forResource: name, withExtension: "yaml", subdirectory: "Workflows") else {
            throw WorkflowError.workflowNotFound(name)
        }
        return try String(contentsOf: url, encoding: .utf8)
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
        // Try to find workflows using Bundle API
        guard let workflowsURL = Bundle.main.resourceURL?.appendingPathComponent("Workflows", isDirectory: true) else {
            print("Workflows directory not found in bundle")
            return []
        }
        
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: workflowsURL, includingPropertiesForKeys: nil) else {
            print("Could not read contents of Workflows directory")
            return []
        }
        
        let workflows = files
            .filter { $0.pathExtension == "yaml" }
            .map { $0.deletingPathExtension().lastPathComponent }
        
        print("Found \(workflows.count) workflows: \(workflows)")
        return workflows
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

