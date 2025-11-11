//
//  URLInputView.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import SwiftUI

/// Text field for custom workflow URL
struct URLInputView: View {
    @Binding var url: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter Workflow URL")
                .font(.headline)
                .padding(.horizontal)
            
            TextField("https://example.com/workflow.yaml", text: $url)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(.horizontal)
            
            Text("Only HTTPS URLs are allowed for security")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

