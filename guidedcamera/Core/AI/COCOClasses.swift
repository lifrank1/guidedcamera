//
//  COCOClasses.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// COCO dataset class names (80 classes)
/// YOLO models trained on COCO use these class IDs (0-79)
struct COCOClasses {
    /// Array of 80 COCO class names in order
    static let classNames = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
        "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse",
        "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie",
        "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove",
        "skateboard", "surfboard", "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon",
        "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut",
        "cake", "chair", "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
        "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book",
        "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
    ]
    
    /// Get class name for a given class ID (0-79)
    static func getClassName(for classId: Int) -> String? {
        guard classId >= 0 && classId < classNames.count else {
            return nil
        }
        return classNames[classId]
    }
    
    /// Get class ID for a given class name (case-insensitive)
    static func getClassId(for className: String) -> Int? {
        let lowercased = className.lowercased()
        return classNames.firstIndex { $0.lowercased() == lowercased }
    }
    
    /// Normalize class name (handle variations, synonyms)
    static func normalizeClassName(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        // Handle common synonyms and variations
        let synonyms: [String: String] = [
            "human": "person",
            "people": "person",
            "face": "person", // Face is part of person in COCO
            "hand": "person", // Hand is part of person in COCO
            "body": "person",
            "vehicle": "car",
            "automobile": "car",
            "auto": "car",
            "bike": "bicycle",
            "cycle": "bicycle",
            "motorbike": "motorcycle",
            "plane": "airplane",
            "aircraft": "airplane",
            "truck": "truck",
            "van": "truck",
            "ship": "boat",
            "vessel": "boat",
            "stoplight": "traffic light",
            "traffic signal": "traffic light",
            "hydrant": "fire hydrant",
            "sign": "stop sign",
            "meter": "parking meter",
            "seat": "chair",
            "sofa": "couch",
            "plant": "potted plant",
            "table": "dining table",
            "desk": "dining table",
            "television": "tv",
            "computer": "laptop",
            "phone": "cell phone",
            "mobile": "cell phone",
            "smartphone": "cell phone"
        ]
        
        // Check if it's a direct match
        if getClassId(for: lowercased) != nil {
            return lowercased
        }
        
        // Check synonyms
        if let normalized = synonyms[lowercased] {
            return normalized
        }
        
        // Return original if no match found
        return lowercased
    }
    
    /// Check if a class name exists in COCO (after normalization)
    static func isValidClassName(_ name: String) -> Bool {
        let normalized = normalizeClassName(name)
        return getClassId(for: normalized) != nil
    }
}

