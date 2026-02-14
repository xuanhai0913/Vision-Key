//
//  SettingsView.swift
//  Vision Key
//
//  Simplified settings for Gemini API only
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//

import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let floatingPopupSettingChanged = Notification.Name("floatingPopupSettingChanged")
    static let providerChanged = Notification.Name("providerChanged")
    static let quickCopySettingChanged = Notification.Name("quickCopySettingChanged")
    static let autoPasteSettingChanged = Notification.Name("autoPasteSettingChanged")
    static let ocrSettingChanged = Notification.Name("ocrSettingChanged")
    static let stealthModeSettingChanged = Notification.Name("stealthModeSettingChanged")
    static let autoClickSettingChanged = Notification.Name("autoClickSettingChanged")
    static let autoClickDelayChanged = Notification.Name("autoClickDelayChanged")
}

struct SettingsView: View {
    @Binding var isPresented: Bool
    @State private var geminiAPIKey: String = ""
    @State private var showAPIKey = false
    @State private var validationMessage: String?
    @State private var selectedModel: String = UserDefaults.standard.string(forKey: "gemini_selectedModel") ?? "gemini-2.0-flash"
    
    private let geminiModels = [
        "gemini-2.5-flash",
        "gemini-2.0-flash", 
        "gemini-1.5-flash",
        "gemini-1.5-pro"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Vision Key")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    apiSection
                    featuresSection
                    shortcutsSection
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("v2.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("© 2025 Nguyễn Xuân Hải")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 380, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let key = KeychainHelper.getAPIKey(forKey: "gemini_api_key") {
                geminiAPIKey = key
            }
        }
    }
    
    // MARK: - API Section
    
    private var apiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gemini API", systemImage: "key.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            HStack {
                if showAPIKey {
                    TextField("API Key", text: $geminiAPIKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("API Key", text: $geminiAPIKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: { showAPIKey.toggle() }) {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                
                Button("Save") {
                    saveAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(geminiAPIKey.isEmpty)
            }
            
            if let message = validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(message.contains("✓") ? .green : .red)
            }
            
            HStack {
                Text("Model:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $selectedModel) {
                    ForEach(geminiModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedModel) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "gemini_selectedModel")
                }
            }
            
            Link("Lấy API Key →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                .font(.caption)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tính năng", systemImage: "sparkle")
                .font(.headline)
                .foregroundColor(.purple)
            
            // MIS Mode
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "misModeEnabled") },
                set: { UserDefaults.standard.set($0, forKey: "misModeEnabled") }
            )) {
                HStack {
                    Text("MIS Mode")
                    Text("📚")
                    Spacer()
                }
            }
            .toggleStyle(.switch)
            
            Text("Tối ưu cho môn Hệ thống TTQL (Using MIS)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 2)
            
            Divider()
            
            // Auto-Click
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "autoClickEnabled") },
                set: { 
                    UserDefaults.standard.set($0, forKey: "autoClickEnabled")
                    NotificationCenter.default.post(name: .autoClickSettingChanged, object: $0)
                }
            )) {
                HStack {
                    Text("Auto-Click")
                    Text("🎯")
                    Spacer()
                }
            }
            .toggleStyle(.switch)
            
            Divider()
            
            // Stealth Mode
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "stealthModeEnabled") },
                set: { 
                    UserDefaults.standard.set($0, forKey: "stealthModeEnabled")
                    NotificationCenter.default.post(name: .stealthModeSettingChanged, object: $0)
                }
            )) {
                HStack {
                    Text("Stealth Mode")
                    Text("👻")
                    Spacer()
                }
            }
            .toggleStyle(.switch)
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - Shortcuts Section
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Phím tắt", systemImage: "keyboard")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(spacing: 6) {
                shortcutRow(keys: "⌘⇧M", desc: "Instant Quiz")
                shortcutRow(keys: "⌘⇧.", desc: "Chụp vùng")
                shortcutRow(keys: "⌘⇧,", desc: "Chụp toàn màn")
                shortcutRow(keys: "⌘⇧/", desc: "Voice input")
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(10)
    }
    
    private func shortcutRow(keys: String, desc: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func saveAPIKey() {
        if KeychainHelper.saveAPIKey(geminiAPIKey, forKey: "gemini_api_key") {
            validationMessage = "✓ Đã lưu API Key"
            // Also update for the old key for backward compatibility
            _ = KeychainHelper.saveAPIKey(geminiAPIKey, forKey: "GeminiAPIKey")
        } else {
            validationMessage = "✗ Lỗi khi lưu"
        }
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}

// MARK: - Settings Window Controller

class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    
    private init() {}
    
    func showSettings() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(isPresented: .constant(true))
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Vision Key Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
