//
//  Annotation.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Voice or text annotation linked to captured media
struct Annotation: Codable, Identifiable {
    let id: UUID
    let mediaId: UUID?
    let stepId: String
    let type: AnnotationType
    let content: String
    let createdAt: Date
    
    init(id: UUID = UUID(), mediaId: UUID? = nil, stepId: String, type: AnnotationType, content: String, createdAt: Date = Date()) {
        self.id = id
        self.mediaId = mediaId
        self.stepId = stepId
        self.type = type
        self.content = content
        self.createdAt = createdAt
    }
}

enum AnnotationType: String, Codable {
    case voice
    case text
    case contextualQA
}

