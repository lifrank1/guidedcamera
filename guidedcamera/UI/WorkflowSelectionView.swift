//
//  WorkflowSelectionView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// List of bundled workflows
struct WorkflowSelectionView: View {
    @Binding var selectedWorkflow: String?
    @State private var workflows: [String] = []
    
    var body: some View {
        List {
            if workflows.isEmpty {
                Text("No workflows found. Make sure workflow files are included in the app bundle.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(workflows, id: \.self) { workflow in
                    Button(action: {
                        selectedWorkflow = workflow
                    }) {
                        HStack {
                            Text(workflowName(workflow))
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedWorkflow == workflow {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadWorkflows()
        }
    }
    
    private func loadWorkflows() {
        let found = WorkflowLoader.shared.listBundledWorkflows()
        workflows = found
        print("Found workflows: \(found)")
    }
    
    private func workflowName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

