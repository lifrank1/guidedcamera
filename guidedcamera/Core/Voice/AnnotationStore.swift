//
//  AnnotationStore.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Stores annotations linked to captured media
class AnnotationStore {
    static let shared = AnnotationStore()
    
    private let userDefaults = UserDefaults.standard
    private let annotationsKey = "annotations"
    
    private init() {}
    
    /// Save an annotation
    func save(_ annotation: Annotation) {
        var annotations = loadAll()
        annotations.append(annotation)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(annotations) {
            userDefaults.set(data, forKey: annotationsKey)
        }
    }
    
    /// Load all annotations
    func loadAll() -> [Annotation] {
        guard let data = userDefaults.data(forKey: annotationsKey) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Annotation].self, from: data)) ?? []
    }
    
    /// Get annotations for a specific media item
    func getAnnotations(for mediaId: UUID) -> [Annotation] {
        return loadAll().filter { $0.mediaId == mediaId }
    }
    
    /// Get annotations for a specific step
    func getAnnotations(for stepId: String) -> [Annotation] {
        return loadAll().filter { $0.stepId == stepId }
    }
    
    /// Clear all annotations
    func clear() {
        userDefaults.removeObject(forKey: annotationsKey)
    }
}

