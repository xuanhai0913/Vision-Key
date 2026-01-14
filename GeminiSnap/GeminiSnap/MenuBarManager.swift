//
//  MenuBarManager.swift
//  Vision Key
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
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
    @Published var expertContext: String = ""  // Vai trò chuyên gia (VD: "Toán học", "Lập trình Python")
    @Published var showFloatingPopup: Bool = true  // Hiển thị popup nổi khi có đáp án
    @Published var quickCopyEnabled: Bool = true   // Tự động copy đáp án vào clipboard
    @Published var autoPasteEnabled: Bool = false  // Tự động paste sau khi copy (⌘V)
    @Published var ocrEnabled: Bool = false        // Trích xuất text từ ảnh trước khi gửi AI
    @Published var extractedOCRText: String?       // Text OCR đã trích xuất (hiển thị trong UI)
    @Published var stealthModeEnabled: Bool = false // Chế độ ẩn - chỉ hiện floating popup
    @Published var autoClickEnabled: Bool = false   // Tự động click vào đáp án
    
    // For auto-click feature
    private var lastCaptureRect: CGRect = .zero     // Vị trí capture trên màn hình
    private var lastOCRObservations: [OCRManager.TextObservation] = [] // OCR text với coordinates
    
    private var settingsObserver: NSObjectProtocol?
    
    init() {
        // Load settings from UserDefaults
        loadSettings()
        
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        observeSettingsChanges()
    }
    
    private func loadSettings() {
        // Floating popup (default: true)
        if UserDefaults.standard.object(forKey: "showFloatingPopup") == nil {
            UserDefaults.standard.set(true, forKey: "showFloatingPopup")
        }
        showFloatingPopup = UserDefaults.standard.bool(forKey: "showFloatingPopup")
        
        // Quick copy (default: true)
        if UserDefaults.standard.object(forKey: "quickCopyEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "quickCopyEnabled")
        }
        quickCopyEnabled = UserDefaults.standard.bool(forKey: "quickCopyEnabled")
        
        // Auto paste (default: false - requires accessibility permission)
        autoPasteEnabled = UserDefaults.standard.bool(forKey: "autoPasteEnabled")
        
        // OCR (default: false)
        ocrEnabled = UserDefaults.standard.bool(forKey: "ocrEnabled")
        
        // Stealth mode (default: false)
        stealthModeEnabled = UserDefaults.standard.bool(forKey: "stealthModeEnabled")
        
        // Auto-click (default: false)
        autoClickEnabled = UserDefaults.standard.bool(forKey: "autoClickEnabled")
    }
    
    private func observeSettingsChanges() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .floatingPopupSettingChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newValue = notification.object as? Bool {
                self?.showFloatingPopup = newValue
            }
        }
        
        // Observe quick copy setting
        NotificationCenter.default.addObserver(
            forName: .quickCopySettingChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newValue = notification.object as? Bool {
                self?.quickCopyEnabled = newValue
            }
        }
        
        // Observe auto paste setting
        NotificationCenter.default.addObserver(
            forName: .autoPasteSettingChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newValue = notification.object as? Bool {
                self?.autoPasteEnabled = newValue
            }
        }
        
        // Observe OCR setting
        NotificationCenter.default.addObserver(
            forName: .ocrSettingChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newValue = notification.object as? Bool {
                self?.ocrEnabled = newValue
            }
        }
        
        // Observe stealth mode setting
        NotificationCenter.default.addObserver(
            forName: .stealthModeSettingChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newValue = notification.object as? Bool {
                self?.stealthModeEnabled = newValue
            }
        }
        
        // Observe auto-click setting
        NotificationCenter.default.addObserver(
            forName: .autoClickSettingChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newValue = notification.object as? Bool {
                self?.autoClickEnabled = newValue
            }
        }
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
        createNewPopover()
    }
    
    private func createNewPopover() {
        // Always create a fresh popover to avoid reuse issues
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
        // Recreate popover if it was closed or doesn't exist
        if popover == nil || popover?.contentViewController == nil {
            createNewPopover()
        }
        
        if let button = statusItem?.button, let pop = popover {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func closePopover() {
        // Use close() instead of performClose() to be safer
        popover?.close()
    }
    
    // MARK: - Screen Capture
    
    func triggerScreenCapture() {
        // Close popover before capture
        closePopover()
        
        // Delay to ensure popover is closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startScreenCapture(fullscreen: false)
        }
    }
    
    func triggerFullscreenCapture() {
        // Close popover before capture
        closePopover()
        
        // Delay to ensure popover is closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startScreenCapture(fullscreen: true)
        }
    }
    
    private func startScreenCapture(fullscreen: Bool) {
        let captureCompletion: (NSImage?) -> Void = { [weak self] image in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let image = image {
                    self.capturedImage = image
                    self.resultText = nil
                    self.errorMessage = nil
                    
                    // In stealth mode, don't show popover
                    if !self.stealthModeEnabled {
                        self.showPopover()
                    }
                    
                    self.analyzeImage(image)
                } else {
                    // User cancelled or permission issue
                    // Only show popover if not in stealth mode
                    if !self.stealthModeEnabled {
                        self.showPopover()
                    }
                }
            }
        }
        
        if fullscreen {
            ScreenCaptureManager.shared.captureFullScreen(completion: captureCompletion)
        } else {
            ScreenCaptureManager.shared.captureScreen(completion: captureCompletion)
        }
    }
    
    // MARK: - Voice Input
    
    @Published var isVoiceRecording = false
    
    func triggerVoiceInput() {
        if isVoiceRecording {
            // Stop recording and process
            VoiceInputManager.shared.finishRecording { [weak self] text in
                guard let self = self, let voiceText = text, !voiceText.isEmpty else {
                    self?.isVoiceRecording = false
                    return
                }
                self.isVoiceRecording = false
                self.processVoiceQuery(voiceText)
            }
        } else {
            // Start recording
            isVoiceRecording = true
            isLoading = false
            resultText = nil
            errorMessage = nil
            
            // Update language based on current setting
            let langCode = AIServiceManager.shared.currentLanguage == .vietnamese ? "vi-VN" : "en-US"
            VoiceInputManager.shared.currentLanguage = langCode
            
            VoiceInputManager.shared.startRecording { [weak self] result in
                DispatchQueue.main.async {
                    self?.isVoiceRecording = false
                    switch result {
                    case .success(let text):
                        if !text.isEmpty {
                            self?.processVoiceQuery(text)
                        }
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                        self?.showPopover()
                    }
                }
            }
            
            // Show popover with recording indicator
            showPopover()
        }
    }
    
    private func processVoiceQuery(_ query: String) {
        isLoading = true
        resultText = nil
        capturedImage = nil
        errorMessage = nil
        
        // For voice queries, we send text directly to AI without image
        // We'll add a method to AIServiceManager for text-only queries
        analyzeText(query)
    }
    
    private func analyzeText(_ text: String) {
        guard let apiKey = KeychainHelper.getAPIKey(forKey: AIServiceManager.shared.currentProviderType.keychainKey) else {
            errorMessage = "API Key not configured"
            isLoading = false
            return
        }
        
        let provider = AIServiceManager.shared.currentProviderType
        let model = AIServiceManager.shared.currentModel
        let lang = AIServiceManager.shared.currentLanguage
        let prompt = answerMode.buildPrompt(expertContext: expertContext.isEmpty ? nil : expertContext, language: lang)
        
        // Build request for text query
        let fullPrompt = "\(prompt)\n\nCâu hỏi: \(text)"
        
        // Use Gemini/OpenAI text API (simplified - just send to current provider)
        // For now, create a simple image with the question text
        // In future, could add text-only API endpoints
        
        isLoading = true
        
        // Create a simple request based on provider
        switch provider {
        case .gemini:
            sendGeminiTextQuery(fullPrompt, apiKey: apiKey, model: model)
        case .openai:
            sendOpenAITextQuery(fullPrompt, apiKey: apiKey, model: model)
        case .deepseek:
            sendDeepseekTextQuery(fullPrompt, apiKey: apiKey, model: model)
        }
    }
    
    private func sendGeminiTextQuery(_ prompt: String, apiKey: String, model: String) {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    self?.handleVoiceResult(text)
                } else {
                    self?.errorMessage = "Failed to parse response"
                }
            }
        }.resume()
    }
    
    private func sendOpenAITextQuery(_ prompt: String, apiKey: String, model: String) {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 2048
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let text = message["content"] as? String {
                    self?.handleVoiceResult(text)
                } else {
                    self?.errorMessage = "Failed to parse response"
                }
            }
        }.resume()
    }
    
    private func sendDeepseekTextQuery(_ prompt: String, apiKey: String, model: String) {
        let url = URL(string: "https://api.deepseek.com/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 2048
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let text = message["content"] as? String {
                    self?.handleVoiceResult(text)
                } else {
                    self?.errorMessage = "Failed to parse response"
                }
            }
        }.resume()
    }
    
    private func handleVoiceResult(_ text: String) {
        let displayText: String
        if answerMode == .tracNghiem {
            displayText = extractFinalAnswer(from: text) ?? text
        } else {
            displayText = text
        }
        resultText = displayText
        
        // Quick copy
        if quickCopyEnabled {
            copyToClipboard(displayText)
        }
        
        // Floating popup
        if showFloatingPopup && answerMode == .tracNghiem {
            FloatingAnswerPanel.shared.show(answer: displayText, autoDismissAfter: 4) { [weak self] in
                self?.showPopover()
            }
        }
        
        // Save to history
        HistoryManager.shared.addItem(
            provider: AIServiceManager.shared.currentProviderType.rawValue,
            model: AIServiceManager.shared.currentModel,
            mode: answerMode.rawValue,
            expertContext: expertContext.isEmpty ? nil : expertContext,
            answer: displayText,
            image: nil
        )
    }
    
    // MARK: - AI Analysis
    
    private func analyzeImage(_ image: NSImage) {
        isLoading = true
        errorMessage = nil
        resultText = nil
        
        AIServiceManager.shared.analyzeImage(
            image,
            mode: answerMode,
            expertContext: expertContext.isEmpty ? nil : expertContext
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let text):
                    // Lọc chỉ lấy FINAL_ANSWER nếu ở chế độ Trắc nghiệm
                    let displayText: String
                    if self.answerMode == .tracNghiem {
                        displayText = self.extractFinalAnswer(from: text) ?? text
                    } else {
                        displayText = text
                    }
                    self.resultText = displayText
                    
                    // Quick Copy: Tự động copy vào clipboard
                    if self.quickCopyEnabled {
                        self.copyToClipboard(displayText)
                        
                        // Auto Paste: Tự động paste (chỉ trong Trắc nghiệm mode)
                        if self.autoPasteEnabled && self.answerMode == .tracNghiem {
                            // Delay nhỏ để đảm bảo clipboard đã cập nhật
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.simulatePaste()
                            }
                        }
                    }
                    
                    // Show floating popup if enabled (only in Trắc nghiệm mode for quick answer)
                    if self.showFloatingPopup && self.answerMode == .tracNghiem {
                        FloatingAnswerPanel.shared.show(
                            answer: displayText,
                            autoDismissAfter: 4
                        ) { [weak self] in
                            // On tap: open main popover
                            self?.showPopover()
                        }
                    }
                    
                    // Auto-Click: Tự động click vào đáp án
                    if self.autoClickEnabled && self.answerMode == .tracNghiem {
                        self.performAutoClick(forAnswer: displayText)
                    }
                    
                    // Save to history
                    HistoryManager.shared.addItem(
                        provider: AIServiceManager.shared.currentProviderType.rawValue,
                        model: AIServiceManager.shared.currentModel,
                        mode: self.answerMode.rawValue,
                        expertContext: self.expertContext.isEmpty ? nil : self.expertContext,
                        answer: displayText,
                        image: self.capturedImage
                    )
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Clipboard & Paste
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func simulatePaste() {
        // Simulate Cmd+V keystroke
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down: V with Cmd
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
        // Key up: V with Cmd
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func simulateClick(at point: CGPoint) {
        // Create mouse click events at the specified coordinates
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Mouse down
        let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        
        // Small delay for more realistic click
        usleep(50000) // 50ms
        
        // Mouse up
        let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
        
        print("🎯 Auto-clicked at: (\(point.x), \(point.y))")
    }
    
    private func performAutoClick(forAnswer answer: String) {
        guard let image = capturedImage else {
            print("❌ Auto-click: No captured image")
            return
        }
        
        // Extract clean answer letter (e.g., "A" from "A, C" or "A.")
        let cleanAnswer = answer.uppercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .first(where: { !$0.isEmpty }) ?? answer.uppercased()
        
        let imageSize = image.size
        
        // Run OCR to get text with coordinates
        OCRManager.shared.extractTextWithCoordinates(from: image, imageSize: imageSize) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let observations):
                self.lastOCRObservations = observations
                
                // Find the answer coordinate
                if let clickPoint = OCRManager.shared.findAnswerCoordinate(
                    answer: cleanAnswer,
                    in: observations,
                    imageSize: imageSize,
                    captureRect: self.lastCaptureRect
                ) {
                    // Click ngay lập tức (không delay)
                    self.simulateClick(at: clickPoint)
                } else {
                    print("⚠️ Auto-click: Could not find answer '\(cleanAnswer)' in OCR results")
                }
                
            case .failure(let error):
                print("❌ Auto-click OCR failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Lọc tất cả FINAL_ANSWER: từ response (hỗ trợ nhiều câu hỏi)
    private func extractFinalAnswer(from text: String) -> String? {
        var answers: [String] = []
        let lines = text.components(separatedBy: "\n")
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            
            // Kiểm tra xem dòng có chứa FINAL_ANSWER: không
            if let range = line.range(of: "FINAL_ANSWER:", options: .caseInsensitive) {
                var answer = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                
                // Nếu đáp án nằm trên nhiều dòng (VD: code block), lấy tiếp
                i += 1
                while i < lines.count {
                    let nextLine = lines[i]
                    // Dừng khi gặp FINAL_ANSWER tiếp theo hoặc dòng trống đôi
                    if nextLine.range(of: "FINAL_ANSWER:", options: .caseInsensitive) != nil {
                        i -= 1  // Quay lại để vòng ngoài xử lý
                        break
                    }
                    // Dừng khi gặp câu hỏi mới (Câu 1, Câu 2, **Câu, etc.)
                    if nextLine.range(of: "^\\s*(Câu|\\*\\*Câu|\\d+[\\.\\)])", options: .regularExpression) != nil {
                        i -= 1
                        break
                    }
                    // Thêm dòng vào đáp án
                    if !nextLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        answer += "\n" + nextLine
                    } else if answer.contains("```") {
                        // Trong code block, giữ dòng trống
                        answer += "\n"
                    } else {
                        // Dòng trống = kết thúc đáp án
                        break
                    }
                    i += 1
                }
                
                let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedAnswer.isEmpty {
                    answers.append(trimmedAnswer)
                }
            }
            i += 1
        }
        
        // If we found FINAL_ANSWER patterns, return them
        if !answers.isEmpty {
            if answers.count == 1 {
                return answers[0]
            } else {
                return answers.enumerated().map { index, answer in
                    "**Câu \(index + 1):** \(answer)"
                }.joined(separator: "\n\n")
            }
        }
        
        // FALLBACK: Nếu không tìm thấy FINAL_ANSWER, thử tìm đáp án khác
        // Tìm các pattern như "Đáp án: A", "Chọn: B", "Answer: C", "The answer is D"
        let fallbackPatterns = [
            "(?:đáp án|chọn|answer|chọn đáp án|the answer is|câu trả lời|kết luận)[:\\s]+([A-D])",
            "(?:→|=>|->|là)[\\s]*([A-D])(?:[\\s\\.,]|$)",
            "^\\s*\\*\\*([A-D])\\*\\*",  // **A**
            "\\bchọn\\s+([A-D])\\b"
        ]
        
        for pattern in fallbackPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let answerRange = Range(match.range(at: 1), in: text) {
                let answer = String(text[answerRange]).uppercased()
                return answer
            }
        }
        
        // FALLBACK 2: Nếu vẫn không tìm được, tìm chữ A/B/C/D đơn lẻ ở cuối text
        let lastLines = text.components(separatedBy: "\n").suffix(5)
        for line in lastLines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Kiểm tra dòng chỉ có 1 chữ A-D
            if trimmed.count == 1 && "ABCD".contains(trimmed.uppercased()) {
                return trimmed.uppercased()
            }
            // Hoặc dòng có format như "A." hoặc "A)" ở đầu
            if let first = trimmed.first, "ABCD".contains(first.uppercased()) {
                if trimmed.count == 1 || (trimmed.count >= 2 && ".):".contains(trimmed[trimmed.index(after: trimmed.startIndex)])) {
                    return String(first).uppercased()
                }
            }
        }
        
        return nil
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
