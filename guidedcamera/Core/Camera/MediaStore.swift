//
//  MediaStore.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import UIKit

/// Manages storage of captured media
class MediaStore {
    static let shared = MediaStore()
    
    private let fileManager = FileManager.default
    private var mediaDirectory: URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("CapturedMedia", isDirectory: true)
    }
    
    private init() {
        createMediaDirectoryIfNeeded()
    }
    
    private func createMediaDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: mediaDirectory.path) {
            try? fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Save captured photo
    func savePhoto(_ image: UIImage, for sessionId: String, stepId: String) throws -> URL {
        let fileName = "\(sessionId)_\(stepId)_\(UUID().uuidString).jpg"
        let fileURL = mediaDirectory.appendingPathComponent(fileName)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw MediaStoreError.imageEncodingFailed
        }
        
        try imageData.write(to: fileURL)
        return fileURL
    }
    
    /// Save captured video
    func saveVideo(from sourceURL: URL, for sessionId: String, stepId: String) throws -> URL {
        let fileName = "\(sessionId)_\(stepId)_\(UUID().uuidString).mov"
        let destinationURL = mediaDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    /// Get all media files for a session
    func getMediaFiles(for sessionId: String) -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: mediaDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.lastPathComponent.hasPrefix(sessionId) }
    }
    
    /// Delete media file
    func deleteMedia(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
}

enum MediaStoreError: LocalizedError {
    case imageEncodingFailed
    
    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode image"
        }
    }
}

