//
//  SetupView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// Initial screen for workflow selection
struct SetupView: View {
    @State private var selectedTab = 0
    @State private var showingCapture = false
    @State private var selectedWorkflow: String?
    @State private var customURL: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Guided Camera")
                    .font(.largeTitle)
                    .bold()
                    .padding()
                
                Picker("Workflow Source", selection: $selectedTab) {
                    Text("Bundled").tag(0)
                    Text("Custom URL").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    WorkflowSelectionView(selectedWorkflow: $selectedWorkflow)
                } else {
                    URLInputView(url: $customURL)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button(action: startSession) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isLoading ? "Loading..." : "Start Session")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canStart ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!canStart || isLoading)
                .padding()
                
                // Debug info
                if selectedTab == 0 {
                    Text("Selected: \(selectedWorkflow ?? "none")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                // Request permissions when view appears
                Task {
                    await PermissionManager.shared.requestAllPermissions()
                }
            }
            .sheet(isPresented: $showingCapture) {
                if let workflow = selectedWorkflow {
                    CaptureView(workflowName: workflow)
                }
            }
        }
    }
    
    private var canStart: Bool {
        if selectedTab == 0 {
            return selectedWorkflow != nil
        } else {
            return !customURL.isEmpty && URL(string: customURL) != nil
        }
    }
    
    private func startSession() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let sessionManager = SessionManager.shared
                
                if selectedTab == 0, let workflow = selectedWorkflow {
                    _ = try await sessionManager.startSession(withBundledWorkflow: workflow)
                } else if !customURL.isEmpty {
                    _ = try await sessionManager.startSession(withRemoteURL: customURL)
                } else {
                    return
                }
                
                await MainActor.run {
                    isLoading = false
                    showingCapture = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

