//
//  guidedcameraApp.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

@main
struct guidedcameraApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                CaptureTabView()
                    .tabItem {
                        Label("Capture", systemImage: "camera.fill")
                    }
                
                ReportsView()
                    .tabItem {
                        Label("Reports", systemImage: "doc.text.fill")
                    }
            }
        }
    }
}
