//
//  MenuBarManager.swift
//  Vision Key
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
//

import SwiftUI
import AppKit
import ApplicationServices

class MenuBarManager: ObservableObject {
    private enum SmartFillInputType {
        case shortField
        case longField
    }

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
    private var smartFillFocusedElement: AXUIElement?
    private var smartFillFocusedRole: String?
    private var smartFillFocusedExistingLength: Int = 0
    private var smartFillTargetInputType: SmartFillInputType = .shortField
    private var smartFillWritingModeEnabledForCapture: Bool = false
    private var smartFillSourceAppPID: pid_t?
    private var smartFillSourceBundleID: String?
    
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
    
    // MARK: - Instant Quiz Capture
    
    /// Instant Quiz Mode: ⌘+⇧+N
    /// - Captures fullscreen immediately (no region selection)
    /// - Uses the fastest available model
    /// - Forces Trắc nghiệm mode for quick answer
    /// - Auto-clicks answer immediately
    /// - Only shows minimal floating popup
    func triggerInstantQuizCapture() {
        // Close popover before capture
        closePopover()
        
        // Minimal delay for instant response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startInstantQuizCapture()
        }
    }
    
    private func startInstantQuizCapture() {
        // Use fullscreen capture for instant mode (faster, no selection needed)
        ScreenCaptureManager.shared.captureFullScreen { [weak self] image in
            DispatchQueue.main.async {
                guard let self = self, let image = image else { return }
                
                // Get the capture rect (set by captureFullScreen)
                self.lastCaptureRect = ScreenCaptureManager.shared.lastCaptureRect
                
                self.capturedImage = image
                self.resultText = nil
                self.errorMessage = nil
                self.isLoading = true
                
                // Force Trắc nghiệm mode for instant quiz
                let savedMode = self.answerMode
                self.answerMode = .tracNghiem
                
                // Use fastest model
                self.analyzeImageWithFastestModel(image) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isLoading = false
                        self.answerMode = savedMode
                        
                        switch result {
                        case .success(let text):
                            let answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.resultText = answer
                            
                            // Check if stealth mode - skip popup if enabled
                            let stealthMode = UserDefaults.standard.bool(forKey: "stealthModeEnabled")
                            if !stealthMode {
                                // Show minimal floating popup only if not in stealth mode
                                FloatingAnswerPanel.shared.show(
                                    answer: answer,
                                    autoDismissAfter: 3
                                ) { [weak self] in
                                    self?.showPopover()
                                }
                            }
                            
                            // Copy to clipboard
                            self.copyToClipboard(answer)
                            
                            // Extract first answer letter for auto-click
                            let firstAnswer = self.extractFirstAnswerLetter(from: answer)
                            print("🔍 Instant Mode - Answer: '\(answer)', FirstLetter: '\(firstAnswer)', AutoClickEnabled: \(self.autoClickEnabled)")
                            print("🔍 CaptureRect: \(self.lastCaptureRect)")
                            
                            if !firstAnswer.isEmpty {
                                // Always auto-click in instant mode (ignore settings)
                                print("🎯 Triggering auto-click for: \(firstAnswer)")
                                self.performAutoClick(forAnswer: firstAnswer)
                            } else {
                                print("⚠️ No answer letter extracted from: \(answer)")
                            }
                            
                            // Save to history
                            HistoryManager.shared.addItem(
                                provider: "Instant",
                                model: "flash",
                                mode: AnswerMode.tracNghiem.rawValue,
                                expertContext: nil,
                                answer: answer,
                                image: image
                            )
                            
                        case .failure(let error):
                            self.errorMessage = error.localizedDescription
                            // Show error in floating popup
                            FloatingAnswerPanel.shared.show(
                                answer: "❌ Error: \(error.localizedDescription)",
                                autoDismissAfter: 4
                            ) { [weak self] in
                                self?.showPopover()
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Analyze image with fastest available model
    private func analyzeImageWithFastestModel(_ image: NSImage, completion: @escaping (Result<String, APIError>) -> Void) {
        // Priority: Gemini flash models (fastest with vision support)
        let fastModels = [
            ("gemini-2.5-flash", AIProviderType.gemini),
            ("gemini-2.0-flash", AIProviderType.gemini),
            ("gemini-flash-latest", AIProviderType.gemini),
            ("gpt-4o-mini", AIProviderType.openai)
        ]
        
        // Check if Knowledge Base is enabled
        let knowledgeContext = KnowledgeBaseManager.shared.isEnabled 
            ? KnowledgeBaseManager.shared.buildContextPrompt() 
            : ""
        
        // Custom prompt for instant quiz - supports multiple questions and multi-select
        let instantPrompt = """
        \(knowledgeContext)Nhìn ảnh và trả lời TẤT CẢ câu hỏi trắc nghiệm trong ảnh.
        
        FORMAT TRẢ LỜI (KHÔNG giải thích):
        [số câu]:[đáp án]
        
        QUY TẮC:
        - Nếu câu hỏi cho chọn NHIỀU đáp án: 2:A,C,D
        - Nếu câu có 5-7 options (A-G): vẫn trả lời bình thường, ví dụ: 3:E hoặc 3:F,G
        - Nhiều câu cách nhau bởi dấu cách: 2:B 3:A,C 4:E
        
        VÍ DỤ:
        - Câu đơn đáp án: 2:B 3:C 4:A
        - Câu nhiều đáp án: 2:A,C,D 3:B
        - Câu có option E,F,G: 5:F 6:A,E,G
        
        Nếu chỉ có 1 câu không rõ số, chỉ trả lời: B (hoặc A,C nếu nhiều đáp án)
        
        QUAN TRỌNG: Chỉ output đáp án, không viết gì khác.
        """
        
        // Find first available fast model
        for (modelId, providerType) in fastModels {
            if let apiKey = AIServiceManager.shared.nextAPIKey(for: providerType), !apiKey.isEmpty {
                providerType.provider.analyzeImage(image, apiKey: apiKey, model: modelId, prompt: instantPrompt, completion: completion)
                return
            }
        }
        
        // Fallback to current provider with standard prompt
        AIServiceManager.shared.analyzeImage(
            image,
            mode: .tracNghiem,
            expertContext: expertContext.isEmpty ? nil : expertContext,
            completion: completion
        )
    }
    
    // MARK: - Smart Fill Capture (CMD+SHIFT+/)

    /// Smart Fill mode:
    /// - Capture selected region
    /// - Generate concise Tu luan answer
    /// - Auto-fill focused input if possible
    /// - If no focused input: show concise popup content to fill
    func triggerSmartFillCapture() {
        closePopover()

        // Capture focused input before user starts selecting capture region.
        smartFillFocusedElement = captureFocusedInputElement()
        smartFillTargetInputType = inferSmartFillInputType()
        smartFillWritingModeEnabledForCapture = shouldUseAdvancedWritingMode(for: smartFillTargetInputType)
        smartFillSourceAppPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        smartFillSourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.startSmartFillCapture()
        }
    }

    private func startSmartFillCapture() {
        ScreenCaptureManager.shared.captureScreen { [weak self] image in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let image = image else {
                    self.smartFillFocusedElement = nil
                    self.resetSmartFillCaptureContext()
                    return
                }

                self.capturedImage = image
                self.resultText = nil
                self.errorMessage = nil
                self.isLoading = true

                let prompt = self.buildSmartFillPrompt(
                    language: AIServiceManager.shared.currentLanguage,
                    targetInputType: self.smartFillTargetInputType,
                    writingModeEnabled: self.smartFillWritingModeEnabledForCapture
                )

                AIServiceManager.shared.analyzeImageWithCustomPrompt(image, prompt: prompt) { [weak self] result in
                    DispatchQueue.main.async {
                        self?.handleSmartFillResult(result, image: image, retryStep: 0)
                    }
                }
            }
        }
    }

    private func handleSmartFillResult(_ result: Result<String, APIError>, image: NSImage, retryStep: Int) {
        isLoading = false

        switch result {
        case .success(let text):
            let fillText = normalizeSmartFillText(text)

            if isLikelyPromptEcho(fillText) {
                if retryStep >= 2 {
                    errorMessage = "AI đang lặp lại đề. Hãy capture rõ hơn hoặc thử lại model khác."
                    FloatingAnswerPanel.shared.show(
                        answer: "⚠️ AI đang lặp đề, thử capture lại rõ hơn",
                        autoDismissAfter: 4
                    ) { }
                    resetSmartFillCaptureContext()
                    return
                }

                isLoading = true
                let retryPrompt: String

                if retryStep == 0 {
                    retryPrompt = buildSmartFillRetryPrompt(
                        language: AIServiceManager.shared.currentLanguage,
                        writingModeEnabled: smartFillWritingModeEnabledForCapture
                    )
                } else {
                    retryPrompt = buildSmartFillRescuePrompt(
                        language: AIServiceManager.shared.currentLanguage,
                        writingModeEnabled: smartFillWritingModeEnabledForCapture,
                        capturedPromptText: fillText
                    )
                }

                AIServiceManager.shared.analyzeImageWithCustomPrompt(image, prompt: retryPrompt) { [weak self] retryResult in
                    DispatchQueue.main.async {
                        self?.handleSmartFillResult(retryResult, image: image, retryStep: retryStep + 1)
                    }
                }
                return
            }

            if smartFillWritingModeEnabledForCapture && isLikelyIncompleteWriting(fillText) && retryStep < 2 {
                isLoading = true
                let retryPrompt = buildSmartFillRetryPrompt(
                    language: AIServiceManager.shared.currentLanguage,
                    writingModeEnabled: true
                )

                AIServiceManager.shared.analyzeImageWithCustomPrompt(image, prompt: retryPrompt) { [weak self] retryResult in
                    DispatchQueue.main.async {
                        self?.handleSmartFillResult(retryResult, image: image, retryStep: retryStep + 1)
                    }
                }
                return
            }

            resultText = fillText

            let hadFocusedInput = smartFillFocusedElement != nil
            var didAutoFill = false
            var didFallbackPaste = false

            if let focusedElement = smartFillFocusedElement {
                didAutoFill = fillTextIntoFocusedInput(fillText, element: focusedElement)

                if !didAutoFill {
                    didFallbackPaste = attemptSmartFillPasteFallback(fillText)
                }
            }
            smartFillFocusedElement = nil

            // Always ensure user can paste manually when auto-fill is not possible.
            if quickCopyEnabled || (!didAutoFill && !didFallbackPaste) {
                copyToClipboard(fillText)
            }

            let popupText = buildSmartFillPopupText(
                fillText,
                didAutoFill: didAutoFill,
                didFallbackPaste: didFallbackPaste,
                hadFocusedInput: hadFocusedInput
            )
            FloatingAnswerPanel.shared.show(answer: popupText, autoDismissAfter: didAutoFill ? 2.5 : 6) { }

            resetSmartFillCaptureContext()

            HistoryManager.shared.addItem(
                provider: AIServiceManager.shared.currentProviderType.rawValue,
                model: AIServiceManager.shared.currentModel,
                mode: "Smart Fill",
                expertContext: expertContext.isEmpty ? nil : expertContext,
                answer: fillText,
                image: image
            )

        case .failure(let error):
            smartFillFocusedElement = nil
            resetSmartFillCaptureContext()
            errorMessage = error.localizedDescription

            FloatingAnswerPanel.shared.show(
                answer: "❌ \(error.localizedDescription)",
                autoDismissAfter: 4
            ) { }
        }
    }

    private func buildSmartFillPrompt(
        language: ResponseLanguage,
        targetInputType: SmartFillInputType,
        writingModeEnabled: Bool
    ) -> String {
        let expertLine = expertContext.isEmpty ? "" : "Bối cảnh chuyên gia: \(expertContext)."
        let targetGuide = targetInputType == .longField
            ? "Đây là ô nhập dài (textarea)"
            : "Đây là ô nhập ngắn (text field)"

        // Writing mode: always use English-only prompt for best quality output
        if writingModeEnabled {
            let (minWords, maxWords) = writingWordRange()
            let expertHint = expertContext.isEmpty ? "" : "The writer's background/context: \(expertContext). "
            return """
            \(expertHint)You are a skilled human essay writer. Read the essay question from the image carefully and write a complete, well-structured essay in ENGLISH.

            ESSAY STRUCTURE — write 4 natural paragraphs in this order, NO labels or headings:
            1. Introduction (2–3 sentences): Open with a natural, engaging observation about the topic. End with a clear personal stance.
            2. First body paragraph (4–5 sentences): Your strongest argument. Support it with a specific real-world example or personal reasoning. Flow naturally.
            3. Second body paragraph (4–5 sentences): A second angle or counter-argument addressed. Ground it with another concrete example.
            4. Conclusion (2–3 sentences): Restate your view in fresh words. Close with a thoughtful final remark — not a generic summary.

            WRITING STYLE — make it sound like a real student, NOT an AI:
            - Vary sentence length: mix short punchy sentences with longer analytical ones.
            - Use natural transitions: "That said,", "What's interesting is", "To put it simply," instead of "Furthermore," "In addition," "It is worth noting that".
            - Express opinion directly: "I firmly believe", "From my perspective", "I've come to think" — not "It can be argued that".
            - Include one specific real example (a country, study, or everyday scenario) to ground the argument.
            - Avoid starting sentences with "The" three times in a row. Avoid passive voice when active sounds more natural.
            - Do NOT use: "In today's world", "In conclusion,", "To sum up,", "It is undeniable that", "plays a crucial role".

            TARGET: \(writingPresetDescriptionEN()) style, \(minWords)–\(maxWords) words.
            OUTPUT: Only the essay text — no labels, no headings, no explanations. Paste-ready.
            """
        }

        if targetInputType == .shortField {
            return """
            \(expertLine)
            \(targetGuide).
            Read the image and provide the exact short answer to fill this field.

            REQUIREMENTS:
            - Output only paste-ready text.
            - Max 25 words.
            - No markdown, no bullets, no explanation.
            - Do not copy the prompt text from the image.
            """
        }

        return """
        \(expertLine)
        \(targetGuide).
        Read the image and provide the exact answer content for this input.

        REQUIREMENTS:
        - Output only paste-ready text.
        - Keep it coherent in 2-5 sentences.
        - No markdown, no bullets, no meta explanation.
        - Do not copy the prompt text from the image.
        """
    }

    private func buildSmartFillRetryPrompt(language: ResponseLanguage, writingModeEnabled: Bool) -> String {
        // Writing mode retry: always English for consistency
        if writingModeEnabled {
            let (minWords, maxWords) = writingWordRange()
            return """
            The previous attempt did not meet essay quality standards. Rewrite the full essay from scratch.

            ESSAY STRUCTURE — 4 natural paragraphs, NO labels or headings:
            1. Introduction (2–3 sentences): Hook + clear personal stance.
            2. First body paragraph (4–5 sentences): Strongest argument with a real example.
            3. Second body paragraph (4–5 sentences): Second angle with a concrete example.
            4. Conclusion (2–3 sentences): Fresh restatement + thoughtful closing remark.

            STYLE: Sound like a real student. Vary sentence length. Use direct opinion ("I believe", "From my experience").
            AVOID: "In today's world", "In conclusion", "It is undeniable", "plays a crucial role", bullet points, headings.
            TARGET: \(writingPresetDescriptionEN()), \(minWords)–\(maxWords) words.
            OUTPUT: Essay text only — no labels, no explanations. Paste-ready.
            """
        }
        }

        return """
        The previous output did not satisfy the input-fill requirements. Rewrite it.

        REQUIREMENTS:
        - Do not copy the prompt from the image.
        - Return only the final answer text to paste.
        - No markdown, no labels, no explanations.
        """
    }

    private func buildSmartFillRescuePrompt(
        language: ResponseLanguage,
        writingModeEnabled: Bool,
        capturedPromptText: String
    ) -> String {
        let promptSnippet = String(capturedPromptText.prefix(600))

        if language == .vietnamese {
            if writingModeEnabled {
                let (minWords, maxWords) = writingWordRange()
                return """
                Đây là đề bài OCR đã nhận diện từ ảnh:
                "\(promptSnippet)"

                YÊU CẦU CỰC KỲ QUAN TRỌNG:
                - Viết BÀI TRẢ LỜI hoàn chỉnh \(minWords)-\(maxWords) từ.
                - Tuyệt đối KHÔNG được sao chép nguyên văn câu nào từ đề bài phía trên.
                - Phải diễn đạt lại bằng lời văn của bạn, có quan điểm cá nhân rõ ràng.
                - Chỉ output bài trả lời để dán vào ô input.
                """
            }

            return """
            Đây là nội dung đề bài OCR:
            "\(promptSnippet)"

            Hãy trả lời câu hỏi này bằng nội dung cuối cùng để nộp.
            - Không sao chép lại đề.
            - Không markdown, không nhãn.
            - Chỉ output phần trả lời.
            """
        }

        if writingModeEnabled {
            let (minWords, maxWords) = writingWordRange()
            return """
            This is the OCR-detected prompt from the image:
            "\(promptSnippet)"

            CRITICAL REQUIREMENTS:
            - Write a complete response of \(minWords)-\(maxWords) words.
            - Do NOT copy any full sentence from the prompt above.
            - Paraphrase the task and provide a clear personal stance.
            - Output only the final response text for pasting.
            """
        }

        return """
        This is the OCR-detected task text:
        "\(promptSnippet)"

        Provide only the final answer content to submit.
        - Do not repeat the prompt text.
        - No markdown, no labels.
        """
    }

    private func shouldUseAdvancedWritingMode(for targetInputType: SmartFillInputType) -> Bool {
        let enabled = UserDefaults.standard.object(forKey: "smartFillAdvancedWritingEnabled") as? Bool ?? true
        guard enabled else {
            return false
        }

        let context = expertContext.lowercased()
        let writingHints = ["writing", "ielts", "toefl", "essay", "task 1", "task 2", "thi writing"]
        let looksLikeWriting = writingHints.contains { context.contains($0) }

        if answerMode == .tuLuan {
            return true
        }

        if looksLikeWriting {
            return true
        }

        return targetInputType == .longField && smartFillFocusedExistingLength > 30
    }

    private func inferSmartFillInputType() -> SmartFillInputType {
        if smartFillFocusedRole == kAXTextAreaRole as String {
            return .longField
        }

        if smartFillFocusedExistingLength > 120 {
            return .longField
        }

        return .shortField
    }

    private func writingPresetDescriptionVN() -> String {
        switch UserDefaults.standard.string(forKey: "smartFillWritingPreset") ?? "IELTS Task 2 - Balanced" {
        case "IELTS Task 2 - Band 7+":
            return "IELTS Task 2 Band 7+ (lập luận sâu, từ vựng học thuật)"
        case "Academic Formal":
            return "Academic Formal (trang trọng, chính xác, giàu liên kết)"
        default:
            return "IELTS Task 2 Balanced (rõ ràng, tự nhiên, dễ dùng)"
        }
    }

    private func writingPresetDescriptionEN() -> String {
        switch UserDefaults.standard.string(forKey: "smartFillWritingPreset") ?? "IELTS Task 2 - Balanced" {
        case "IELTS Task 2 - Band 7+":
            return "IELTS Task 2 Band 7+ style (deeper argumentation, stronger academic vocabulary)"
        case "Academic Formal":
            return "Academic formal style (precise, cohesive, formal tone)"
        default:
            return "balanced IELTS Task 2 style (clear, natural, practical)"
        }
    }

    private func writingWordRange() -> (Int, Int) {
        let target = UserDefaults.standard.integer(forKey: "smartFillWritingWordTarget")
        let normalizedTarget = target == 0 ? 260 : max(200, min(350, target))
        let minWords = max(180, normalizedTarget - 25)
        let maxWords = min(380, normalizedTarget + 25)
        return (minWords, maxWords)
    }

    private func isLikelyIncompleteWriting(_ text: String) -> Bool {
        let count = wordCount(text)
        let (minWords, _) = writingWordRange()
        return count < minWords
    }

    private func wordCount(_ text: String) -> Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    private func isLikelyPromptEcho(_ text: String) -> Bool {
        let lower = text.lowercased()

        let promptIndicators = [
            "discuss both views and give your own opinion",
            "some people believe",
            "đề bài",
            "task 2",
            "write about the following",
            "hãy thảo luận"
        ]

        let answerIndicators = [
            "in my opinion",
            "i believe",
            "to conclude",
            "on the one hand",
            "on the other hand",
            "theo tôi",
            "tôi cho rằng",
            "kết luận"
        ]

        let hasPromptSignal = promptIndicators.contains { lower.contains($0) }
        let hasAnswerSignal = answerIndicators.contains { lower.contains($0) }

        if hasPromptSignal && !hasAnswerSignal {
            return true
        }

        // If output is very short but still contains classic prompt phrases,
        // it is likely prompt-echo instead of a real answer.
        if lower.count < 260,
           lower.contains("discuss both views") {
            return true
        }

        return false
    }

    private func captureFocusedInputElement() -> AXUIElement? {
        guard AXIsProcessTrusted() else {
            smartFillFocusedRole = nil
            smartFillFocusedExistingLength = 0
            return nil
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?

        let status = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard status == .success, let focusedValue = focusedValue else {
            smartFillFocusedRole = nil
            smartFillFocusedExistingLength = 0
            return nil
        }

        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        if isEditableInputElement(focusedElement) {
            smartFillFocusedRole = roleString(for: focusedElement)
            smartFillFocusedExistingLength = currentTextLength(for: focusedElement)
            return focusedElement
        }

        smartFillFocusedRole = nil
        smartFillFocusedExistingLength = 0
        return nil
    }

    private func roleString(for element: AXUIElement) -> String {
        var roleValue: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        guard roleStatus == .success else {
            return ""
        }
        return roleValue as? String ?? ""
    }

    private func currentTextLength(for element: AXUIElement) -> Int {
        var valueRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        guard status == .success,
              let value = valueRef as? String else {
            return 0
        }
        return value.count
    }

    private func resetSmartFillCaptureContext() {
        smartFillFocusedElement = nil
        smartFillFocusedRole = nil
        smartFillFocusedExistingLength = 0
        smartFillTargetInputType = .shortField
        smartFillWritingModeEnabledForCapture = false
        smartFillSourceAppPID = nil
        smartFillSourceBundleID = nil
    }

    private func isEditableInputElement(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleStatus == .success ? (roleValue as? String ?? "") : ""

        let editableRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField"
        ]

        if editableRoles.contains(role) {
            return true
        }

        var isSettable = DarwinBoolean(false)
        let settableStatus = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &isSettable
        )

        return settableStatus == .success && isSettable.boolValue
    }

    private func fillTextIntoFocusedInput(_ text: String, element: AXUIElement) -> Bool {
        _ = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )

        let status = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        return status == .success
    }

    private func attemptSmartFillPasteFallback(_ text: String) -> Bool {
        copyToClipboard(text)

        var targetApp: NSRunningApplication?

        if let pid = smartFillSourceAppPID {
            targetApp = NSRunningApplication(processIdentifier: pid)
        }

        if targetApp == nil,
           let bundleID = smartFillSourceBundleID,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            targetApp = app
        }

        targetApp?.activate(options: [.activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.simulatePaste()
        }

        return targetApp != nil
    }

    private func normalizeSmartFillText(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "FINAL_ANSWER:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "\\r", with: "")

        cleaned = cleaned
            .replacingOccurrences(of: "\\n+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let removablePrefixes = ["Đề bài:", "Đề:", "Prompt:", "Question:"]
        for prefix in removablePrefixes where cleaned.hasPrefix(prefix) {
            cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") && cleaned.count > 1 {
            cleaned = String(cleaned.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if cleaned.isEmpty {
            return AIServiceManager.shared.currentLanguage == .vietnamese
                ? "Không có nội dung phù hợp để điền."
                : "No suitable content to fill."
        }

        return cleaned
    }

    private func buildSmartFillPopupText(
        _ text: String,
        didAutoFill: Bool,
        didFallbackPaste: Bool,
        hadFocusedInput: Bool
    ) -> String {
        let concise = concisePopupText(text, maxLength: 120)

        if didAutoFill {
            return "Đã điền: \(concise)"
        }

        if didFallbackPaste {
            return "Đã dán: \(concise)"
        }

        if hadFocusedInput {
            return "Điền tay: \(concise)"
        }

        return "Điền: \(concise)"
    }

    private func concisePopupText(_ text: String, maxLength: Int) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard collapsed.count > maxLength else {
            return collapsed
        }

        return String(collapsed.prefix(maxLength)) + "..."
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
        guard let apiKey = AIServiceManager.shared.nextAPIKey(for: AIServiceManager.shared.currentProviderType) else {
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
        
        // Get delay from settings (default 0.15s)
        let delay = UserDefaults.standard.double(forKey: "autoClickDelay")
        let actualDelay = delay == 0 ? 0.15 : delay
        
        print("🔍 performAutoClick - Answer: '\(cleanAnswer)', CaptureRect: \(lastCaptureRect)")
        
        // Run OCR to get text with coordinates
        OCRManager.shared.extractTextWithCoordinates(from: image, imageSize: imageSize) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let observations):
                self.lastOCRObservations = observations
                print("📝 OCR found \(observations.count) text observations")
                
                // Find the answer coordinate
                if let clickPoint = OCRManager.shared.findAnswerCoordinate(
                    answer: cleanAnswer,
                    in: observations,
                    imageSize: imageSize,
                    captureRect: self.lastCaptureRect
                ) {
                    print("🎯 Found click point: \(clickPoint)")
                    // Apply delay before clicking
                    DispatchQueue.main.asyncAfter(deadline: .now() + actualDelay) {
                        self.simulateClick(at: clickPoint)
                        // Update popup to show click success
                        FloatingAnswerPanel.shared.show(
                            answer: "\(cleanAnswer) ✓ Clicked!",
                            autoDismissAfter: 2
                        ) { }
                        print("✅ Auto-clicked at (\(clickPoint.x), \(clickPoint.y))")
                    }
                } else {
                    print("⚠️ Could not find '\(cleanAnswer)' in OCR. All observations:")
                    for obs in observations {
                        print("  - '\(obs.text)' at \(obs.boundingBox)")
                    }
                    // Update popup to show not found
                    DispatchQueue.main.async {
                        FloatingAnswerPanel.shared.show(
                            answer: "\(cleanAnswer) (OCR không tìm thấy)",
                            autoDismissAfter: 3
                        ) { }
                    }
                }
                
            case .failure(let error):
                print("❌ OCR failed: \(error.localizedDescription)")
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
                if let normalizedMulti = normalizeQuestionAnswerPairs(answers[0]) {
                    return normalizedMulti
                }
                return answers[0]
            } else {
                return answers.enumerated().map { index, answer in
                    "**Câu \(index + 1):** \(answer)"
                }.joined(separator: "\n\n")
            }
        }

        if let normalizedMulti = normalizeQuestionAnswerPairs(text) {
            return normalizedMulti
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

    private func normalizeQuestionAnswerPairs(_ text: String) -> String? {
        let pattern = "(?i)(?:câu|question|q)?\\s*(\\d{1,3})\\s*[:\\.)-]\\s*([A-G](?:\\s*,\\s*[A-G])*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        guard matches.count >= 2 else {
            return nil
        }

        var pairs: [String] = []
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let qRange = Range(match.range(at: 1), in: text),
                  let aRange = Range(match.range(at: 2), in: text) else {
                continue
            }

            let questionNumber = String(text[qRange])
            let answer = String(text[aRange])
                .uppercased()
                .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

            pairs.append("\(questionNumber):\(answer)")
        }

        return pairs.isEmpty ? nil : pairs.joined(separator: " ")
    }
    
    /// Extract first answer letter from multi-question format (e.g., "2:B 3:C 4:A" -> "B")
    private func extractFirstAnswerLetter(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern 1: "2:B" format - extract first answer after colon
        if let colonRange = trimmed.range(of: ":") {
            let afterColon = trimmed[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)
            let letter = afterColon.prefix(1).uppercased()
            if "ABCDEFG".contains(letter) {
                return letter
            }
        }
        
        // Pattern 2: Simple "B" letter
        if trimmed.count == 1 && "ABCD".contains(trimmed.uppercased()) {
            return trimmed.uppercased()
        }
        
        // Pattern 3: Find first A/B/C/D letter in text
        for char in trimmed.uppercased() {
            if "ABCD".contains(char) {
                return String(char)
            }
        }
        
        return ""
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
