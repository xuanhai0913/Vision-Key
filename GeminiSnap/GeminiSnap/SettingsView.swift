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
    enum APIKeyHealthStatus {
        case testing
        case alive(String)
        case dead(String)
    }

    @Binding var isPresented: Bool
    @State private var geminiAPIKey: String = ""
    @State private var geminiAPIKeysText: String = ""
    @State private var showAPIKey = false
    @State private var validationMessage: String?
    @State private var isTestingKeyPool = false
    @State private var keyHealthResults: [String: APIKeyHealthStatus] = [:]
    @State private var testedKeys: [String] = []
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
            if let key = KeychainHelper.getAPIKey(forKey: KeychainHelper.geminiKey)
                ?? KeychainHelper.getAPIKey(forKey: "gemini_api_key")
                ?? KeychainHelper.getAPIKey(forKey: "GeminiAPIKey") {
                geminiAPIKey = key
            }

            let pool = KeychainHelper.getAPIKeyPool(forKey: KeychainHelper.geminiKey)
            if !pool.isEmpty {
                geminiAPIKeysText = pool.joined(separator: "\n")
            } else if !geminiAPIKey.isEmpty {
                geminiAPIKeysText = geminiAPIKey
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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("API Key Pool (mỗi dòng 1 key)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(parseAPIKeyPoolText(geminiAPIKeysText).count) keys")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                TextEditor(text: $geminiAPIKeysText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 72)
                    .padding(4)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)

                HStack {
                    Button("Test All Keys") {
                        testAllAPIKeys()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingKeyPool || parseAPIKeyPoolText(geminiAPIKeysText).isEmpty)

                    Spacer()
                    Button("Save Key Pool") {
                        saveAPIKeyPool()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingKeyPool || parseAPIKeyPoolText(geminiAPIKeysText).isEmpty)
                }

                if isTestingKeyPool {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Đang test key pool...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if !testedKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(testedKeys, id: \.self) { key in
                            apiKeyHealthRow(key: key, status: keyHealthResults[key])
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(6)
                }
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
            
            // Knowledge Base
            Toggle(isOn: Binding(
                get: { KnowledgeBaseManager.shared.isEnabled },
                set: { KnowledgeBaseManager.shared.isEnabled = $0 }
            )) {
                HStack {
                    Text("Knowledge Base")
                    Text("📚")
                    Spacer()
                }
            }
            .toggleStyle(.switch)
            
            HStack {
                let count = KnowledgeBaseManager.shared.activeDocuments.count
                Text(count > 0 ? "\(count) tài liệu đang active" : "Chưa có tài liệu nào")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    KnowledgeBaseWindowController.shared.showKnowledgeBase()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.caption2)
                        Text("Quản lý")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
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
                shortcutRow(keys: "⌘⇧/", desc: "Smart Fill tự luận")
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
        if KeychainHelper.saveAPIKey(geminiAPIKey, forKey: KeychainHelper.geminiKey) {
            validationMessage = "✓ Đã lưu API Key"
            // Also update legacy keys for backward compatibility.
            _ = KeychainHelper.saveAPIKey(geminiAPIKey, forKey: "gemini_api_key")
            _ = KeychainHelper.saveAPIKey(geminiAPIKey, forKey: "GeminiAPIKey")

            if parseAPIKeyPoolText(geminiAPIKeysText).isEmpty {
                geminiAPIKeysText = geminiAPIKey
                _ = KeychainHelper.saveAPIKeyPool([geminiAPIKey], forKey: KeychainHelper.geminiKey)
            }
        } else {
            validationMessage = "✗ Lỗi khi lưu"
        }
    }

    private func testAllAPIKeys() {
        let keys = parseAPIKeyPoolText(geminiAPIKeysText)
        guard !keys.isEmpty else {
            validationMessage = "✗ Chưa có key để test"
            return
        }

        isTestingKeyPool = true
        testedKeys = keys
        keyHealthResults = Dictionary(uniqueKeysWithValues: keys.map { ($0, .testing) })
        validationMessage = "Đang kiểm tra \(keys.count) key..."

        testAPIKeysSequentially(keys: keys, index: 0, aliveCount: 0)
    }

    private func testAPIKeysSequentially(keys: [String], index: Int, aliveCount: Int) {
        if index >= keys.count {
            isTestingKeyPool = false
            let deadCount = keys.count - aliveCount
            validationMessage = "✓ Test xong: \(aliveCount) sống, \(deadCount) chết"
            return
        }

        let key = keys[index]
        GeminiProvider().validateAndFetchModels(apiKey: key) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let models):
                    self.keyHealthResults[key] = .alive("\(models.count) models")
                    self.testAPIKeysSequentially(keys: keys, index: index + 1, aliveCount: aliveCount + 1)

                case .failure(let error):
                    self.keyHealthResults[key] = .dead(error.localizedDescription)
                    self.testAPIKeysSequentially(keys: keys, index: index + 1, aliveCount: aliveCount)
                }
            }
        }
    }

    @ViewBuilder
    private func apiKeyHealthRow(key: String, status: APIKeyHealthStatus?) -> some View {
        let masked = maskAPIKey(key)

        HStack(spacing: 8) {
            Circle()
                .fill(colorForStatus(status))
                .frame(width: 8, height: 8)

            Text(masked)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text(textForStatus(status))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func maskAPIKey(_ key: String) -> String {
        if key.count <= 12 {
            return key
        }

        let prefix = key.prefix(6)
        let suffix = key.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    private func textForStatus(_ status: APIKeyHealthStatus?) -> String {
        guard let status else { return "Chưa test" }

        switch status {
        case .testing:
            return "Đang test"
        case .alive(let detail):
            return "Sống • \(detail)"
        case .dead(let message):
            let compact = message.replacingOccurrences(of: "\n", with: " ")
            return "Chết • \(compact)"
        }
    }

    private func colorForStatus(_ status: APIKeyHealthStatus?) -> Color {
        guard let status else { return .secondary }

        switch status {
        case .testing:
            return .orange
        case .alive:
            return .green
        case .dead:
            return .red
        }
    }

    private func saveAPIKeyPool() {
        let keys = parseAPIKeyPoolText(geminiAPIKeysText)
        guard !keys.isEmpty else {
            validationMessage = "✗ Chưa có key hợp lệ"
            return
        }

        let savedPool = KeychainHelper.saveAPIKeyPool(keys, forKey: KeychainHelper.geminiKey)
        let savedPrimary = KeychainHelper.saveAPIKey(keys[0], forKey: KeychainHelper.geminiKey)

        if savedPool && savedPrimary {
            geminiAPIKey = keys[0]
            _ = KeychainHelper.saveAPIKey(keys[0], forKey: "gemini_api_key")
            _ = KeychainHelper.saveAPIKey(keys[0], forKey: "GeminiAPIKey")
            validationMessage = "✓ Đã lưu \(keys.count) API keys (xoay vòng)"
        } else {
            validationMessage = "✗ Lỗi khi lưu key pool"
        }
    }

    private func parseAPIKeyPoolText(_ text: String) -> [String] {
        var seen = Set<String>()
        var orderedKeys: [String] = []

        let lines = text
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for key in lines where !seen.contains(key) {
            seen.insert(key)
            orderedKeys.append(key)
        }

        return orderedKeys
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
