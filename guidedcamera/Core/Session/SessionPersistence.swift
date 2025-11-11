//
//  SessionPersistence.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Handles persistence of session state
class SessionPersistence {
    static let shared = SessionPersistence()
    
    private let userDefaults = UserDefaults.standard
    private let sessionKey = "currentSessionState"
    
    private init() {}
    
    /// Save session state
    func save(_ state: SessionState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        userDefaults.set(data, forKey: sessionKey)
    }
    
    /// Load session state
    func load() -> SessionState? {
        guard let data = userDefaults.data(forKey: sessionKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SessionState.self, from: data)
    }
    
    /// Clear saved session
    func clear() {
        userDefaults.removeObject(forKey: sessionKey)
    }
}

