//
//  ContentView.swift
//  GeminiSnap
//
//  Main content view displayed in the popover
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var menuBarManager: MenuBarManager
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Main content
            ResultView(
                image: menuBarManager.capturedImage,
                resultText: menuBarManager.resultText,
                errorMessage: menuBarManager.errorMessage,
                isLoading: menuBarManager.isLoading,
                onCopy: {
                    // Notification or haptic feedback could go here
                },
                onNewCapture: {
                    menuBarManager.triggerScreenCapture()
                },
                onClear: {
                    menuBarManager.clearResult()
                }
            )
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                // App icon and title
                HStack(spacing: 8) {
                    Image(systemName: "eye.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("GeminiSnap")
                            .font(.headline)
                        Text("AI Screen Assistant")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // API Key status indicator
                    apiKeyStatusIndicator
                    
                    // Settings button
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                    
                    // Menu
                    Menu {
                        Button(action: { menuBarManager.triggerScreenCapture() }) {
                            Label("Capture Screen", systemImage: "camera.viewfinder")
                        }
                        .keyboardShortcut(".", modifiers: [.command, .shift])
                        
                        Divider()
                        
                        Button(action: { showSettings = true }) {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .keyboardShortcut(",", modifiers: .command)
                        
                        Divider()
                        
                        Button(action: { menuBarManager.quit() }) {
                            Label("Quit GeminiSnap", systemImage: "power")
                        }
                        .keyboardShortcut("q", modifiers: .command)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            
            // Answer Mode Toggle
            answerModeToggle
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
    }
    
    // MARK: - Answer Mode Toggle
    
    private var answerModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(AnswerMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        menuBarManager.answerMode = mode
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.caption)
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        menuBarManager.answerMode == mode
                            ? Color.accentColor
                            : Color.clear
                    )
                    .foregroundColor(
                        menuBarManager.answerMode == mode
                            ? .white
                            : .secondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - API Key Status
    
    @ViewBuilder
    private var apiKeyStatusIndicator: some View {
        let hasKey = KeychainHelper.hasAPIKey()
        
        Button(action: { showSettings = true }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(hasKey ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(hasKey ? "Ready" : "No API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .help(hasKey ? "API Key configured" : "Click to configure API Key")
    }
}

#Preview {
    ContentView(menuBarManager: MenuBarManager())
        .frame(width: 400, height: 500)
}
