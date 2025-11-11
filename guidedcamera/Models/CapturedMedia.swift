//
//  CapturedMedia.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import UIKit

/// Represents a captured photo or video with metadata
struct CapturedMedia: Codable, Identifiable {
    let id: UUID
    let stepId: String
    let type: MediaType
    let fileURL: URL
    let capturedAt: Date
    let metadata: MediaMetadata
    
    init(id: UUID = UUID(), stepId: String, type: MediaType, fileURL: URL, capturedAt: Date = Date(), metadata: MediaMetadata = MediaMetadata()) {
        self.id = id
        self.stepId = stepId
        self.type = type
        self.fileURL = fileURL
        self.capturedAt = capturedAt
        self.metadata = metadata
    }
}

enum MediaType: String, Codable {
    case photo
    case video
}

struct MediaMetadata: Codable {
    var location: LocationData?
    var deviceInfo: String?
    var qualityScore: Double?
    var detectedObjects: [String]?
    
    init() {
        self.location = nil
        self.deviceInfo = nil
        self.qualityScore = nil
        self.detectedObjects = nil
    }
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

