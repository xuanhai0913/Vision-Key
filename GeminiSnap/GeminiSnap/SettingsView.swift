//
//  SettingsView.swift
//  GeminiSnap
//
//  Settings UI for API key configuration
//

import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var saveStatus: SaveStatus = .idle
    
    enum SaveStatus {
        case idle
        case saving
        case success
        case error(String)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // API Key Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Gemini API Key")
                    .font(.headline)
                
                Text("Enter your Google Gemini API key. Get one from [Google AI Studio](https://aistudio.google.com/app/apikey).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Group {
                        if showKey {
                            TextField("Enter API Key", text: $apiKey)
                        } else {
                            SecureField("Enter API Key", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    
                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showKey ? "Hide API Key" : "Show API Key")
                }
                
                // Status message
                statusView
            }
            
            Spacer()
            
            // Hotkey info
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcut")
                    .font(.headline)
                
                HStack {
                    Text("Capture Screen:")
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        KeyCap(text: "⌘")
                        KeyCap(text: "⇧")
                        KeyCap(text: ".")
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Buttons
            HStack {
                Button("Delete Key") {
                    deleteKey()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveKey()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKey.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380, height: 360)
        .onAppear {
            loadCurrentKey()
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch saveStatus {
        case .idle:
            EmptyView()
        case .saving:
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Saving...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .success:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("API Key saved successfully!")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .error(let message):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func loadCurrentKey() {
        if let existingKey = KeychainHelper.getAPIKey() {
            apiKey = existingKey
        }
    }
    
    private func saveKey() {
        saveStatus = .saving
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if KeychainHelper.saveAPIKey(apiKey) {
                saveStatus = .success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isPresented = false
                }
            } else {
                saveStatus = .error("Failed to save API key")
            }
        }
    }
    
    private func deleteKey() {
        KeychainHelper.deleteAPIKey()
        apiKey = ""
        saveStatus = .idle
    }
}

// MARK: - Key Cap View

struct KeyCap: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}
