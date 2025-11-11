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

