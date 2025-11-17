//
//  VisualOverlayView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// SwiftUI overlay for composition guides, bounding boxes, progress
struct VisualOverlayView: View {
    let overlays: [String]?
    let progress: Double
    let detectedObjects: [DetectedObject]?
    
    init(overlays: [String]?, progress: Double, detectedObjects: [DetectedObject]? = nil) {
        self.overlays = overlays
        self.progress = progress
        self.detectedObjects = detectedObjects
    }
    
    var body: some View {
        ZStack {
            // Grid overlay
            if overlays?.contains("grid") == true {
                GridOverlay()
            }
            
            // Horizon overlay
            if overlays?.contains("horizon") == true {
                HorizonOverlay()
            }
            
            // Rule of thirds
            if overlays?.contains("rule_of_thirds") == true {
                RuleOfThirdsOverlay()
            }
            
            // Bounding boxes for detected objects
            if let objects = detectedObjects, !objects.isEmpty {
                BoundingBoxOverlay(objects: objects)
            }
            
            // Progress indicator
            ProgressOverlay(progress: progress)
        }
    }
}

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Vertical lines
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                
                path.move(to: CGPoint(x: width * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: width * 2 / 3, y: height))
                
                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                
                path.move(to: CGPoint(x: 0, y: height * 2 / 3))
                path.addLine(to: CGPoint(x: width, y: height * 2 / 3))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
    }
}

struct HorizonOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let centerY = height / 2
                
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: width, y: centerY))
            }
            .stroke(Color.yellow.opacity(0.7), lineWidth: 2)
        }
    }
}

struct RuleOfThirdsOverlay: View {
    var body: some View {
        GridOverlay()
    }
}

struct ProgressOverlay: View {
    let progress: Double
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 200)
                    .padding()
            }
        }
    }
}

struct BoundingBoxOverlay: View {
    let objects: [DetectedObject]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(objects.enumerated()), id: \.offset) { index, object in
                let normalizedBox = normalizeBoundingBox(object.boundingBox, to: geometry.size)
                
                ZStack(alignment: .topLeading) {
                    // Bounding box rectangle
                    Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: normalizedBox.width, height: normalizedBox.height)
                        .position(
                            x: normalizedBox.midX,
                            y: normalizedBox.midY
                        )
                    
                    // Label with confidence
                    Text("\(object.label) \(Int(object.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(4)
                        .position(
                            x: normalizedBox.minX + 40,
                            y: normalizedBox.minY - 10
                        )
                }
            }
        }
    }
    
    /// Normalize bounding box from model coordinates (640x640) to view coordinates
    private func normalizeBoundingBox(_ box: CGRect, to viewSize: CGSize) -> CGRect {
        // Model input is 640x640, but we need to account for aspect ratio
        // Assuming camera preview fills the view
        let scaleX = viewSize.width / 640.0
        let scaleY = viewSize.height / 640.0
        
        return CGRect(
            x: box.origin.x * scaleX,
            y: box.origin.y * scaleY,
            width: box.width * scaleX,
            height: box.height * scaleY
        )
    }
}

