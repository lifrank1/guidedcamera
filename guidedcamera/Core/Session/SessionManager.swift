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
        print("🚀 [SessionManager] Starting session with bundled workflow: \(name)")
        
        do {
            print("🚀 [SessionManager] Step 1: Loading YAML workflow...")
            let yamlContent = try loader.loadBundledWorkflow(name)
            print("✅ [SessionManager] YAML loaded successfully (\(yamlContent.count) characters)")
            
            print("🚀 [SessionManager] Step 2: Compiling workflow...")
            let plan = try await compiler.compile(yamlContent)
            print("✅ [SessionManager] Workflow compiled successfully")
            print("✅ [SessionManager] Plan has \(plan.steps.count) steps")
            
            print("🚀 [SessionManager] Step 3: Creating session...")
            let session = CaptureSession()
            session.start(with: plan)
            print("✅ [SessionManager] Session started successfully")
            
            return session
        } catch {
            print("❌ [SessionManager] Failed to start session: \(error)")
            print("❌ [SessionManager] Error type: \(type(of: error))")
            print("❌ [SessionManager] Error description: \(error.localizedDescription)")
            throw error
        }
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

