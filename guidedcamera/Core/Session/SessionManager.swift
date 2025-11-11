//
//  SessionManager.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Coordinates session lifecycle
class SessionManager {
    static let shared = SessionManager()
    
    private let loader = WorkflowLoader.shared
    private let compiler = WorkflowCompiler.shared
    private let persistence = SessionPersistence.shared
    
    private init() {}
    
    /// Load and start a session with a bundled workflow
    func startSession(withBundledWorkflow name: String) async throws -> CaptureSession {
        let yamlContent = try loader.loadBundledWorkflow(name)
        let plan = try await compiler.compile(yamlContent)
        
        let session = CaptureSession()
        session.start(with: plan)
        
        return session
    }
    
    /// Load and start a session with a remote workflow
    func startSession(withRemoteURL urlString: String) async throws -> CaptureSession {
        let yamlContent = try await loader.fetchRemoteWorkflow(from: urlString)
        let plan = try await compiler.compile(yamlContent)
        
        let session = CaptureSession()
        session.start(with: plan)
        
        return session
    }
    
    /// Resume a saved session
    func resumeSession() -> CaptureSession? {
        guard let savedState = persistence.load() else {
            return nil
        }
        return CaptureSession(state: savedState)
    }
    
    /// Clear current session
    func clearSession() {
        persistence.clear()
    }
}

