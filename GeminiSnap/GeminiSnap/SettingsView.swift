//
//  SettingsView.swift
//  Vision Key
//
//  Multi-provider settings with API key management and model selection
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
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
}

struct SettingsView: View {
    @Binding var isPresented: Bool
    @State private var selectedProvider: AIProviderType = AIServiceManager.shared.currentProviderType
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Provider Tabs
            providerTabsView
            
            Divider()
            
            // Provider Settings Content
            ScrollView {
                VStack(spacing: 16) {
                    // API Keys Overview - show status of all providers
                    apiKeysOverviewSection
                    
                    ProviderSettingsView(provider: selectedProvider)
                    
                    // Floating Popup Toggle
                    floatingPopupSection
                    
                    // Hotkey Info
                    hotkeyInfoSection
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(width: 450, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
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
        .padding()
    }
    
    // MARK: - Provider Tabs
    
    private var providerTabsView: some View {
        HStack(spacing: 0) {
            ForEach(AIProviderType.allCases) { provider in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProvider = provider
                        AIServiceManager.shared.currentProviderType = provider
                        NotificationCenter.default.post(name: .providerChanged, object: provider)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: provider.icon)
                            .font(.caption)
                        Text(provider.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        // Status indicator
                        Circle()
                            .fill(KeychainHelper.hasAPIKey(forKey: provider.keychainKey) ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedProvider == provider
                            ? Color.accentColor
                            : Color.clear
                    )
                    .foregroundColor(
                        selectedProvider == provider
                            ? .white
                            : .primary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.1))
    }
    
    // MARK: - API Keys Overview Section
    
    private var apiKeysOverviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentColor)
                Text("API Keys Status")
                    .font(.headline)
                Spacer()
                Text("\(configuredKeysCount)/3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                ForEach(AIProviderType.allCases) { provider in
                    apiKeyStatusRow(for: provider)
                }
            }
            
            if configuredKeysCount == 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Cần ít nhất 1 API key để sử dụng")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            } else if configuredKeysCount > 1 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Có thể chuyển đổi giữa các provider nếu cần")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var configuredKeysCount: Int {
        AIProviderType.allCases.filter { KeychainHelper.hasAPIKey(forKey: $0.keychainKey) }.count
    }
    
    private func apiKeyStatusRow(for provider: AIProviderType) -> some View {
        let hasKey = KeychainHelper.hasAPIKey(forKey: provider.keychainKey)
        let isActive = selectedProvider == provider
        
        return HStack {
            // Provider icon and name
            HStack(spacing: 8) {
                Image(systemName: provider.icon)
                    .frame(width: 16)
                    .foregroundColor(isActive ? .accentColor : .secondary)
                
                Text(provider.rawValue)
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)
            }
            
            Spacer()
            
            // Status badge
            if hasKey {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Ready")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.15))
                .cornerRadius(10)
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("No Key")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(10)
            }
            
            // Switch button if has key and not active
            if hasKey && !isActive {
                Button(action: {
                    withAnimation {
                        selectedProvider = provider
                        AIServiceManager.shared.currentProviderType = provider
                    }
                }) {
                    Text("Use")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            } else if isActive {
                Text("Active")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    // MARK: - Floating Popup Section
    
    private var floatingPopupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Settings")
                .font(.headline)
            
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "showFloatingPopup") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "showFloatingPopup")
                    NotificationCenter.default.post(name: .floatingPopupSettingChanged, object: newValue)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Floating Answer Popup")
                        .font(.subheadline)
                    Text("Show quick answer popup at screen corner")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            
            Divider()
            
            // Quick Copy Toggle
            Toggle(isOn: Binding(
                get: { 
                    if UserDefaults.standard.object(forKey: "quickCopyEnabled") == nil {
                        return true // default
                    }
                    return UserDefaults.standard.bool(forKey: "quickCopyEnabled")
                },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "quickCopyEnabled")
                    NotificationCenter.default.post(name: .quickCopySettingChanged, object: newValue)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Copy")
                        .font(.subheadline)
                    Text("Auto copy answer to clipboard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            
            // Auto Paste Toggle
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "autoPasteEnabled") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "autoPasteEnabled")
                    NotificationCenter.default.post(name: .autoPasteSettingChanged, object: newValue)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Auto Paste")
                            .font(.subheadline)
                        Text("⚠️")
                            .font(.caption)
                    }
                    Text("Auto paste answer (Trắc nghiệm mode only)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Requires Accessibility permission")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .toggleStyle(.switch)
            
            Divider()
            
            // OCR Toggle
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "ocrEnabled") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "ocrEnabled")
                    NotificationCenter.default.post(name: .ocrSettingChanged, object: newValue)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("OCR Text Extraction")
                            .font(.subheadline)
                        Text("🔍")
                            .font(.caption)
                    }
                    Text("Extract text from image before AI analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Uses Apple Vision framework")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .toggleStyle(.switch)
            
            Divider()
            
            // Auto-Fallback Toggle
            Toggle(isOn: Binding(
                get: { AIServiceManager.shared.autoFallbackEnabled },
                set: { newValue in
                    AIServiceManager.shared.autoFallbackEnabled = newValue
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Auto-Fallback Provider")
                            .font(.subheadline)
                        Text("🔄")
                            .font(.caption)
                    }
                    Text("Switch to another provider on failure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Requires 2+ API keys configured")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .toggleStyle(.switch)
            
            Divider()
            
            // Stealth Mode Toggle
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "stealthModeEnabled") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "stealthModeEnabled")
                    NotificationCenter.default.post(name: .stealthModeSettingChanged, object: newValue)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Stealth Mode")
                            .font(.subheadline)
                        Text("👻")
                            .font(.caption)
                    }
                    Text("Only show floating popup, hide main panel")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            
            Divider()
            
            // Auto-Click Toggle
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "autoClickEnabled") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "autoClickEnabled")
                    NotificationCenter.default.post(name: .autoClickSettingChanged, object: newValue)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Auto-Click Answer")
                            .font(.subheadline)
                        Text("🎯")
                            .font(.caption)
                    }
                    Text("Automatically click on the detected answer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Requires Accessibility permission")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .toggleStyle(.switch)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Hotkey Info Section
    
    private var hotkeyInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            
            HStack {
                Text("Region Capture:")
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    KeyCap(text: "⌘")
                    KeyCap(text: "⇧")
                    KeyCap(text: ".")
                }
            }
            .font(.subheadline)
            
            HStack {
                Text("Fullscreen Capture:")
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    KeyCap(text: "⌘")
                    KeyCap(text: "⇧")
                    KeyCap(text: ",")
                }
            }
            .font(.subheadline)
            
            HStack {
                HStack(spacing: 4) {
                    Text("Voice Input:")
                        .foregroundColor(.secondary)
                    Text("🎤")
                        .font(.caption)
                }
                Spacer()
                HStack(spacing: 4) {
                    KeyCap(text: "⌘")
                    KeyCap(text: "⇧")
                    KeyCap(text: "/")
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        VStack(spacing: 4) {
            Text("Vision Key v2.0")
                .font(.caption)
                .fontWeight(.medium)
            HStack(spacing: 4) {
                Text("© 2025")
                if let url = URL(string: "https://github.com/xuanhai0913") {
                    Link("Nguyễn Xuân Hải (xuanhai0913)", destination: url)
                } else {
                    Text("Nguyễn Xuân Hải (xuanhai0913)")
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Provider Settings View

struct ProviderSettingsView: View {
    let provider: AIProviderType
    
    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var saveStatus: SaveStatus = .idle
    @State private var availableModels: [AIModel] = []
    @State private var selectedModel: String = ""
    @State private var isValidating: Bool = false
    
    enum SaveStatus {
        case idle
        case saving
        case validating
        case success
        case error(String)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Provider Title
            HStack {
                Image(systemName: provider.icon)
                    .foregroundColor(.accentColor)
                Text("\(provider.rawValue) API Configuration")
                    .font(.headline)
            }
            
            // API Key Help
            providerHelpText
            
            // API Key Input
            HStack {
                Group {
                    if showKey {
                        TextField("Enter \(provider.rawValue) API Key", text: $apiKey)
                    } else {
                        SecureField("Enter \(provider.rawValue) API Key", text: $apiKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                
                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: validateAndSaveKey) {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Validate & Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(apiKey.isEmpty || isValidating)
            }
            
            // Status
            statusView
            
            // Model Selection (if models available)
            if !availableModels.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Selection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Model", selection: $selectedModel) {
                        ForEach(availableModels) { model in
                            HStack {
                                Text(model.name)
                                if model.supportsVision {
                                    Image(systemName: "eye")
                                        .font(.caption2)
                                }
                            }
                            .tag(model.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedModel) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "selectedModel_\(provider.rawValue)")
                    }
                }
            }
            
            // Delete Key Button
            if KeychainHelper.hasAPIKey(forKey: provider.keychainKey) {
                HStack {
                    Spacer()
                    Button(action: deleteKey) {
                        Label("Delete Key", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: provider) { _ in
            loadCurrentSettings()
        }
    }
    
    // MARK: - Provider Help Text
    
    @ViewBuilder
    private var providerHelpText: some View {
        switch provider {
        case .gemini:
            Text("Get your API key from [Google AI Studio](https://aistudio.google.com/app/apikey)")
                .font(.caption)
                .foregroundColor(.secondary)
        case .deepseek:
            Text("Get your API key from [DeepSeek Platform](https://platform.deepseek.com/api_keys)")
                .font(.caption)
                .foregroundColor(.secondary)
        case .openai:
            Text("Get your API key from [OpenAI Platform](https://platform.openai.com/api-keys)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Status View
    
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
        case .validating:
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Validating API key and fetching models...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .success:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("API Key validated and saved!")
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
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentSettings() {
        apiKey = KeychainHelper.getAPIKey(forKey: provider.keychainKey) ?? ""
        selectedModel = UserDefaults.standard.string(forKey: "selectedModel_\(provider.rawValue)") 
            ?? provider.provider.defaultModel
        
        // Load cached models if available
        if let cachedModels = UserDefaults.standard.array(forKey: "cachedModels_\(provider.rawValue)") as? [String] {
            availableModels = cachedModels.map { AIModel(id: $0) }
        }
        
        saveStatus = .idle
    }
    
    private func validateAndSaveKey() {
        isValidating = true
        saveStatus = .validating
        
        provider.provider.validateAndFetchModels(apiKey: apiKey) { result in
            DispatchQueue.main.async {
                isValidating = false
                
                switch result {
                case .success(let models):
                    // Save the key
                    if KeychainHelper.saveAPIKey(apiKey, forKey: provider.keychainKey) {
                        availableModels = models
                        
                        // Cache model IDs
                        UserDefaults.standard.set(models.map { $0.id }, forKey: "cachedModels_\(provider.rawValue)")
                        
                        // Set default model if not selected
                        if selectedModel.isEmpty || !models.contains(where: { $0.id == selectedModel }) {
                            selectedModel = models.first?.id ?? provider.provider.defaultModel
                            UserDefaults.standard.set(selectedModel, forKey: "selectedModel_\(provider.rawValue)")
                        }
                        
                        saveStatus = .success
                        
                        // Clear success after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if case .success = saveStatus {
                                saveStatus = .idle
                            }
                        }
                    } else {
                        saveStatus = .error("Failed to save API key to Keychain")
                    }
                    
                case .failure(let error):
                    saveStatus = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func deleteKey() {
        KeychainHelper.deleteAPIKey(forKey: provider.keychainKey)
        apiKey = ""
        availableModels = []
        selectedModel = ""
        UserDefaults.standard.removeObject(forKey: "cachedModels_\(provider.rawValue)")
        UserDefaults.standard.removeObject(forKey: "selectedModel_\(provider.rawValue)")
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

// MARK: - Settings Window Controller

import AppKit

class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    private var hostingController: NSHostingController<SettingsContentView>?
    
    private override init() {
        super.init()
    }
    
    func showSettings() {
        // If window exists and is visible, just bring to front
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create new window
        let settingsView = SettingsContentView()
        hostingController = NSHostingController(rootView: settingsView)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window?.title = "Vision Key Settings"
        window?.contentViewController = hostingController
        window?.center()
        window?.isReleasedWhenClosed = false
        window?.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeSettings() {
        window?.close()
    }
}

// Settings content view that doesn't need Binding for isPresented
struct SettingsContentView: View {
    @State private var selectedProvider: AIProviderType = AIServiceManager.shared.currentProviderType
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { SettingsWindowController.shared.closeSettings() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Provider Tabs
            HStack(spacing: 0) {
                ForEach(AIProviderType.allCases) { provider in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProvider = provider
                            AIServiceManager.shared.currentProviderType = provider
                            NotificationCenter.default.post(name: .providerChanged, object: provider)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: provider.icon)
                                .font(.caption)
                            Text(provider.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                            Circle()
                                .fill(KeychainHelper.hasAPIKey(forKey: provider.keychainKey) ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedProvider == provider ? Color.accentColor : Color.clear)
                        .foregroundColor(selectedProvider == provider ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.secondary.opacity(0.1))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    ProviderSettingsView(provider: selectedProvider)
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            VStack(spacing: 4) {
                Text("Vision Key v2.0")
                    .font(.caption)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text("© 2025")
                    if let url = URL(string: "https://github.com/xuanhai0913") {
                        Link("Nguyễn Xuân Hải", destination: url)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 450, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
