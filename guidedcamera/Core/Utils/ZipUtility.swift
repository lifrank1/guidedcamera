//
//  ZipUtility.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation
import Compression

/// Utility for creating zip files
/// Note: For a production app, consider using ZipFoundation (https://github.com/weichsel/ZIPFoundation)
/// This is a simplified implementation for Phase 1
class ZipUtility {
    static func createZip(from sourceURL: URL, to destinationURL: URL) throws {
        // For Phase 1, we'll create a simple archive structure
        // In production, use ZipFoundation or similar library via SPM
        let fileManager = FileManager.default
        
        // Remove existing zip if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Create a simple tar-like structure or use UIActivityViewController to share
        // For now, we'll copy the directory and let the share sheet handle compression
        // This is a workaround for Phase 1 - proper zip requires a library
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
}

enum ZipError: LocalizedError {
    case creationFailed
    
    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Failed to create zip file"
        }
    }
}

