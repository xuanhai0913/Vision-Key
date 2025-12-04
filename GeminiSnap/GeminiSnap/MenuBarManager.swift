//
//  MenuBarManager.swift
//  GeminiSnap
//
//  Handles the status bar icon and popover display
//

import SwiftUI
import AppKit

class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    
    @Published var capturedImage: NSImage?
    @Published var isLoading = false
    @Published var resultText: String?
    @Published var errorMessage: String?
    @Published var showSettings = false
    @Published var answerMode: AnswerMode = .tracNghiem  // Chế độ trả lời
    
    init() {
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol for the menu bar icon
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            if let image = NSImage(systemSymbolName: "eye.circle.fill", accessibilityDescription: "GeminiSnap") {
                let configuredImage = image.withSymbolConfiguration(config)
                button.image = configuredImage
            } else {
                button.title = "👁"
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.animates = true
        
        let contentView = ContentView(menuBarManager: self)
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }
    
    private func setupEventMonitor() {
        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
    }
    
    @objc func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func closePopover() {
        popover?.performClose(nil)
    }
    
    // MARK: - Screen Capture
    
    func triggerScreenCapture() {
        // Close popover before capture
        closePopover()
        
        // Delay to ensure popover is closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startScreenCapture()
        }
    }
    
    private func startScreenCapture() {
        ScreenCaptureManager.shared.captureScreen { [weak self] image in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let image = image {
                    self.capturedImage = image
                    self.resultText = nil
                    self.errorMessage = nil
                    self.showPopover()
                    self.analyzeImage(image)
                } else {
                    // User cancelled or permission issue - don't show error
                    // Just reopen popover
                    self.showPopover()
                }
            }
        }
    }
    
    // MARK: - AI Analysis
    
    private func analyzeImage(_ image: NSImage) {
        guard let apiKey = KeychainHelper.getAPIKey(), !apiKey.isEmpty else {
            errorMessage = "API Key not set. Please configure in Settings."
            return
        }
        
        isLoading = true
        errorMessage = nil
        resultText = nil
        
        APIService.shared.analyzeImage(image, apiKey: apiKey, mode: answerMode) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let text):
                    self?.resultText = text
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Actions
    
    func toggleAnswerMode() {
        answerMode = answerMode == .tracNghiem ? .tuLuan : .tracNghiem
    }
    
    func openSettings() {
        showSettings = true
    }
    
    func clearResult() {
        capturedImage = nil
        resultText = nil
        errorMessage = nil
    }
    
    func quit() {
        NSApp.terminate(nil)
    }
    
    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
