//
//  WorkflowCache.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Manages caching of YAML workflows and compiled JSON plans
class WorkflowCache {
    static let shared = WorkflowCache()
    
    private let fileManager = FileManager.default
    private var cacheDirectory: URL {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("Workflows", isDirectory: true)
    }
    
    private init() {
        createCacheDirectoryIfNeeded()
    }
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Cache a YAML workflow file
    func cacheYAML(_ yamlContent: String, for url: URL) throws {
        let fileName = url.lastPathComponent
        let cacheFile = cacheDirectory.appendingPathComponent(fileName)
        try yamlContent.write(to: cacheFile, atomically: true, encoding: .utf8)
    }
    
    /// Retrieve cached YAML for a URL
    func getCachedYAML(for url: URL) -> String? {
        let fileName = url.lastPathComponent
        let cacheFile = cacheDirectory.appendingPathComponent(fileName)
        return try? String(contentsOf: cacheFile, encoding: .utf8)
    }
    
    /// Cache a compiled JSON plan
    func cachePlan(_ plan: WorkflowPlan, for identifier: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(plan)
        let cacheFile = cacheDirectory.appendingPathComponent("\(identifier).json")
        try data.write(to: cacheFile)
    }
    
    /// Retrieve a cached compiled plan
    func getCachedPlan(for identifier: String) -> WorkflowPlan? {
        let cacheFile = cacheDirectory.appendingPathComponent("\(identifier).json")
        guard let data = try? Data(contentsOf: cacheFile) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(WorkflowPlan.self, from: data)
    }
    
    /// Generate cache identifier from YAML content
    func generateCacheIdentifier(from yamlContent: String) -> String {
        let hash = yamlContent.hashValue
        return "plan_\(abs(hash))"
    }
}

