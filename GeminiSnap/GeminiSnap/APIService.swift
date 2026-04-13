//
//  APIService.swift
//  Vision Key
//
//  Multi-provider AI support: Gemini, Deepseek, OpenAI
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
//

import Foundation
import AppKit

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidImage
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidImage:
            return "Failed to encode image"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let message):
            return "API Error: \(message)"
        case .noContent:
            return "No content in response"
        }
    }
}

// MARK: - Response Language

enum ResponseLanguage: String, CaseIterable, Identifiable {
    case vietnamese = "Tiếng Việt"
    case english = "English"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .vietnamese: return "🇻🇳"
        case .english: return "🇬🇧"
        }
    }
    
    var promptInstruction: String {
        switch self {
        case .vietnamese: return "Trả lời bằng tiếng Việt."
        case .english: return "Answer in English."
        }
    }
}

// MARK: - Answer Mode

enum AnswerMode: String, CaseIterable {
    case tracNghiem = "Trắc nghiệm"
    case tuLuan = "Tự luận"
    
    var icon: String {
        switch self {
        case .tracNghiem: return "checkmark.circle.fill"
        case .tuLuan: return "text.alignleft"
        }
    }
    
    func buildPrompt(expertContext: String?, language: ResponseLanguage = .vietnamese) -> String {
        let expertLine = if let expert = expertContext, !expert.isEmpty {
            language == .vietnamese 
                ? "Bạn là chuyên gia \(expert). "
                : "You are an expert in \(expert). "
        } else {
            ""
        }
        
        switch self {
        case .tracNghiem:
            if language == .vietnamese {
                return """
                \(expertLine)QUAN TRỌNG: Chỉ trả lời đáp án, KHÔNG GIẢI THÍCH!
                
                CHỈ TRẢ LỜI ĐÚNG 1 DÒNG DUY NHẤT:
                FINAL_ANSWER: ...
                
                QUY TẮC FORMAT:
                - Nếu chỉ có 1 câu: FINAL_ANSWER: B
                - Nếu có nhiều câu: FINAL_ANSWER: 1:B 2:C 3:A
                - Nếu 1 câu có nhiều đáp án: FINAL_ANSWER: 2:A,C
                - Cho phép đáp án A-G nếu đề có nhiều lựa chọn.
                
                ❌ SAI: Giải thích dài dòng rồi mới đưa đáp án
                ✅ ĐÚNG: FINAL_ANSWER: 1:B 2:A,C 3:F
                
                Chỉ output 1 dòng. Không viết gì khác.
                """
            } else {
                return """
                \(expertLine)IMPORTANT: ONLY answer, NO EXPLANATION!
                
                OUTPUT EXACTLY ONE LINE:
                FINAL_ANSWER: ...
                
                FORMAT RULES:
                - Single question: FINAL_ANSWER: B
                - Multiple questions: FINAL_ANSWER: 1:B 2:C 3:A
                - Multi-select question: FINAL_ANSWER: 2:A,C
                - Allow A-G when options go beyond D.
                
                ❌ WRONG: Long explanation then answer
                ✅ CORRECT: FINAL_ANSWER: 1:B 2:A,C 3:F
                
                Only output 1 line. Nothing else.
                """
            }
        case .tuLuan:
            if language == .vietnamese {
                return """
                \(expertLine)Trả lời bằng tiếng Việt. Giải thích RÕ RÀNG và CHI TIẾT.
                
                - Bài toán: giải từng bước, giải thích công thức
                - Code: giải thích lỗi, tại sao sai, cách sửa
                - Câu hỏi: trả lời đầy đủ với ví dụ nếu cần
                - Văn bản: phân tích và tóm tắt ý chính
                
                Cuối cùng, LUÔN LUÔN tóm tắt bằng:
                
                FINAL_ANSWER: [kết luận/đáp án cuối cùng]
                """
            } else {
                return """
                \(expertLine)Answer in English. Explain CLEARLY and in DETAIL.
                
                - Math: solve step by step, explain formulas
                - Code: explain the error, why it's wrong, how to fix
                - Questions: answer fully with examples if needed
                - Text: analyze and summarize key points
                
                Finally, ALWAYS summarize with:
                
                FINAL_ANSWER: [conclusion/final answer]
                """
            }
        }
    }
}

// MARK: - AI Model

struct AIModel: Identifiable, Hashable {
    let id: String
    let name: String
    let supportsVision: Bool
    
    init(id: String, name: String? = nil, supportsVision: Bool = true) {
        self.id = id
        self.name = name ?? id
        self.supportsVision = supportsVision
    }
}

// MARK: - Provider Type

enum AIProviderType: String, CaseIterable, Identifiable {
    case gemini = "Gemini"
    case deepseek = "DeepSeek"
    case openai = "OpenAI"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .gemini: return "sparkle"
        case .deepseek: return "brain"
        case .openai: return "cube.transparent"
        }
    }
    
    var provider: AIProvider {
        switch self {
        case .gemini: return GeminiProvider()
        case .deepseek: return DeepseekProvider()
        case .openai: return OpenAIProvider()
        }
    }
    
    var keychainKey: String {
        switch self {
        case .gemini: return KeychainHelper.geminiKey
        case .deepseek: return KeychainHelper.deepseekKey
        case .openai: return KeychainHelper.openaiKey
        }
    }
}

// MARK: - AI Provider Protocol

protocol AIProvider {
    var name: String { get }
    var icon: String { get }
    var supportsVision: Bool { get }
    var defaultModel: String { get }
    
    func analyzeImage(
        _ image: NSImage,
        apiKey: String,
        model: String,
        prompt: String,
        completion: @escaping (Result<String, APIError>) -> Void
    )
    
    func validateAndFetchModels(
        apiKey: String,
        completion: @escaping (Result<[AIModel], APIError>) -> Void
    )
}

// MARK: - Gemini Provider

class GeminiProvider: AIProvider {
    let name = "Gemini"
    let icon = "sparkle"
    let supportsVision = true
    let defaultModel = "gemini-2.5-pro"
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    
    func analyzeImage(_ image: NSImage, apiKey: String, model: String, prompt: String, completion: @escaping (Result<String, APIError>) -> Void) {
        guard let imageData = ImageHelper.imageToBase64(image) else {
            completion(.failure(.invalidImage))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)") else {
            completion(.failure(.invalidURL))
            return
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        ["inline_data": ["mime_type": "image/jpeg", "data": imageData]]
                    ]
                ]
            ],
            "generationConfig": ["temperature": 0.0, "topK": 1, "topP": 1, "maxOutputTokens": 4096]
        ]
        
        makeRequest(url: url, body: requestBody, headers: [:]) { data in
            self.parseGeminiResponse(data: data, completion: completion)
        } onError: { error in
            completion(.failure(error))
        }
    }
    
    func validateAndFetchModels(apiKey: String, completion: @escaping (Result<[AIModel], APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/models?key=\(apiKey)") else {
            completion(.failure(.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                        completion(.failure(.apiError(message)))
                        return
                    }
                    
                    if let models = json["models"] as? [[String: Any]] {
                        let aiModels = models.compactMap { model -> AIModel? in
                            guard let name = model["name"] as? String else { return nil }
                            let modelId = name.replacingOccurrences(of: "models/", with: "")
                            let supportedMethods = model["supportedGenerationMethods"] as? [String] ?? []
                            if modelId.contains("gemini") && supportedMethods.contains("generateContent") {
                                return AIModel(id: modelId, supportsVision: true)
                            }
                            return nil
                        }.sorted { $0.id > $1.id }
                        completion(.success(aiModels))
                        return
                    }
                }
                completion(.failure(.invalidResponse))
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
    
    private func parseGeminiResponse(data: Data, completion: @escaping (Result<String, APIError>) -> Void) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                    completion(.failure(.apiError(message)))
                    return
                }
                if let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    completion(.success(text))
                    return
                }
                completion(.failure(.noContent))
            } else {
                completion(.failure(.invalidResponse))
            }
        } catch {
            completion(.failure(.networkError(error)))
        }
    }
    
    private func makeRequest(url: URL, body: [String: Any], headers: [String: String], onSuccess: @escaping (Data) -> Void, onError: @escaping (APIError) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            onError(.networkError(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                onError(.networkError(error))
                return
            }
            guard let data = data else {
                onError(.invalidResponse)
                return
            }
            onSuccess(data)
        }.resume()
    }
}

// MARK: - DeepSeek Provider

class DeepseekProvider: AIProvider {
    let name = "DeepSeek"
    let icon = "brain"
    let supportsVision = false  // DeepSeek chat API doesn't support vision
    let defaultModel = "deepseek-chat"
    
    private let baseURL = "https://api.deepseek.com"
    
    func analyzeImage(_ image: NSImage, apiKey: String, model: String, prompt: String, completion: @escaping (Result<String, APIError>) -> Void) {
        // DeepSeek chat API doesn't support image input
        // Return an error directing user to use Gemini or OpenAI for vision
        completion(.failure(.apiError("DeepSeek hiện tại không hỗ trợ phân tích hình ảnh. Vui lòng sử dụng Gemini hoặc OpenAI cho tính năng này.")))
    }
    
    func validateAndFetchModels(apiKey: String, completion: @escaping (Result<[AIModel], APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/models") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            // Check HTTP status for auth errors
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    completion(.failure(.apiError("Invalid API key")))
                    return
                }
                if httpResponse.statusCode == 200 {
                    // Key is valid, return default models
                    completion(.success([
                        AIModel(id: "deepseek-chat", name: "DeepSeek Chat (Text Only)", supportsVision: false),
                        AIModel(id: "deepseek-reasoner", name: "DeepSeek Reasoner (Text Only)", supportsVision: false)
                    ]))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                        completion(.failure(.apiError(message)))
                        return
                    }
                }
                // Fallback: return default models
                completion(.success([
                    AIModel(id: "deepseek-chat", name: "DeepSeek Chat (Text Only)", supportsVision: false),
                    AIModel(id: "deepseek-reasoner", name: "DeepSeek Reasoner (Text Only)", supportsVision: false)
                ]))
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
}

// MARK: - OpenAI Provider

class OpenAIProvider: AIProvider {
    let name = "OpenAI"
    let icon = "cube.transparent"
    let supportsVision = true
    let defaultModel = "gpt-4o"
    
    private let baseURL = "https://api.openai.com/v1"
    
    func analyzeImage(_ image: NSImage, apiKey: String, model: String, prompt: String, completion: @escaping (Result<String, APIError>) -> Void) {
        guard let imageData = ImageHelper.imageToBase64(image) else {
            completion(.failure(.invalidImage))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(.failure(.invalidURL))
            return
        }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageData)", "detail": "high"]]
                    ]
                ]
            ],
            "max_tokens": 4096,
            "temperature": 0.0
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.networkError(error)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            self.parseOpenAIResponse(data: data, completion: completion)
        }.resume()
    }
    
    func validateAndFetchModels(apiKey: String, completion: @escaping (Result<[AIModel], APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/models") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                        completion(.failure(.apiError(message)))
                        return
                    }
                    
                    if let models = json["data"] as? [[String: Any]] {
                        let visionModelPrefixes = ["gpt-4o", "gpt-4-turbo", "gpt-4-vision"]
                        let aiModels = models.compactMap { model -> AIModel? in
                            guard let id = model["id"] as? String else { return nil }
                            if visionModelPrefixes.contains(where: { id.contains($0) }) {
                                return AIModel(id: id, supportsVision: true)
                            }
                            return nil
                        }.sorted { $0.id > $1.id }
                        
                        if aiModels.isEmpty {
                            completion(.success([
                                AIModel(id: "gpt-4o", name: "GPT-4o", supportsVision: true),
                                AIModel(id: "gpt-4o-mini", name: "GPT-4o Mini", supportsVision: true)
                            ]))
                        } else {
                            completion(.success(aiModels))
                        }
                        return
                    }
                }
                completion(.failure(.invalidResponse))
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
    
    private func parseOpenAIResponse(data: Data, completion: @escaping (Result<String, APIError>) -> Void) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                    completion(.failure(.apiError(message)))
                    return
                }
                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                    return
                }
                completion(.failure(.noContent))
            } else {
                completion(.failure(.invalidResponse))
            }
        } catch {
            completion(.failure(.networkError(error)))
        }
    }
}

// MARK: - Image Helper

class ImageHelper {
    static func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }
}

// MARK: - AI Service Manager

class AIServiceManager {
    static let shared = AIServiceManager()
    
    private init() {}
    
    var currentProviderType: AIProviderType {
        get {
            let raw = UserDefaults.standard.string(forKey: "selectedProvider") ?? "Gemini"
            return AIProviderType(rawValue: raw) ?? .gemini
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedProvider")
        }
    }
    
    var currentModel: String {
        get {
            UserDefaults.standard.string(forKey: "selectedModel_\(currentProviderType.rawValue)")
                ?? currentProviderType.provider.defaultModel
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedModel_\(currentProviderType.rawValue)")
        }
    }
    
    var currentLanguage: ResponseLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: "responseLanguage") ?? ResponseLanguage.vietnamese.rawValue
            return ResponseLanguage(rawValue: raw) ?? .vietnamese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "responseLanguage")
        }
    }
    
    var autoFallbackEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoFallbackEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "autoFallbackEnabled") }
    }
    
    var currentProvider: AIProvider {
        currentProviderType.provider
    }

    private func rotationIndexKey(for providerType: AIProviderType) -> String {
        "apiKeyRotationIndex_\(providerType.rawValue)"
    }

    private func configuredAPIKeys(for providerType: AIProviderType) -> [String] {
        let pool = KeychainHelper.getAPIKeyPool(forKey: providerType.keychainKey)
        if !pool.isEmpty {
            return pool
        }

        guard let key = KeychainHelper.getAPIKey(forKey: providerType.keychainKey), !key.isEmpty else {
            return []
        }

        return [key]
    }

    private func orderedAPIKeysForRequest(providerType: AIProviderType) -> [String] {
        let keys = configuredAPIKeys(for: providerType)
        guard keys.count > 1 else {
            return keys
        }

        let key = rotationIndexKey(for: providerType)
        let startIndex = UserDefaults.standard.integer(forKey: key) % keys.count
        let ordered = Array(keys[startIndex...] + keys[..<startIndex])

        UserDefaults.standard.set((startIndex + 1) % keys.count, forKey: key)
        return ordered
    }

    func nextAPIKey(for providerType: AIProviderType) -> String? {
        orderedAPIKeysForRequest(providerType: providerType).first
    }
    
    /// Get list of providers that have API keys configured
    var availableProviders: [AIProviderType] {
        AIProviderType.allCases.filter { KeychainHelper.hasAPIKey(forKey: $0.keychainKey) }
    }
    
    /// Get next fallback provider (skipping current one)
    func getNextFallbackProvider(after current: AIProviderType) -> AIProviderType? {
        let available = availableProviders.filter { $0 != current && $0.provider.supportsVision }
        return available.first
    }
    
    func analyzeImage(
        _ image: NSImage,
        mode: AnswerMode,
        expertContext: String?,
        language: ResponseLanguage? = nil,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        analyzeImageWithProvider(
            image,
            mode: mode,
            expertContext: expertContext,
            language: language,
            providerType: currentProviderType,
            isRetry: false,
            completion: completion
        )
    }

    func analyzeImageWithCustomPrompt(
        _ image: NSImage,
        prompt: String,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        var finalPrompt = prompt

        if KnowledgeBaseManager.shared.isEnabled {
            let kbContext = KnowledgeBaseManager.shared.buildContextPrompt()
            if !kbContext.isEmpty {
                finalPrompt = kbContext + finalPrompt
            }
        }

        analyzeImageWithPromptAndProvider(
            image,
            prompt: finalPrompt,
            providerType: currentProviderType,
            isRetry: false,
            completion: completion
        )
    }
    
    private func analyzeImageWithProvider(
        _ image: NSImage,
        mode: AnswerMode,
        expertContext: String?,
        language: ResponseLanguage?,
        providerType: AIProviderType,
        isRetry: Bool,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        guard !configuredAPIKeys(for: providerType).isEmpty else {
            // Try fallback if enabled
            if autoFallbackEnabled && !isRetry, let fallback = getNextFallbackProvider(after: providerType) {
                print("⚠️ No API key for \(providerType.rawValue), falling back to \(fallback.rawValue)")
                analyzeImageWithProvider(image, mode: mode, expertContext: expertContext, language: language, providerType: fallback, isRetry: true, completion: completion)
                return
            }
            completion(.failure(.apiError("API Key for \(providerType.rawValue) not set. Please configure in Settings.")))
            return
        }
        
        let lang = language ?? currentLanguage
        var prompt = mode.buildPrompt(expertContext: expertContext, language: lang)
        
        // Inject Knowledge Base context if enabled
        if KnowledgeBaseManager.shared.isEnabled {
            let kbContext = KnowledgeBaseManager.shared.buildContextPrompt()
            if !kbContext.isEmpty {
                prompt = kbContext + prompt
            }
        }

        analyzeImageWithPromptAndProvider(
            image,
            prompt: prompt,
            providerType: providerType,
            isRetry: isRetry,
            completion: completion
        )
    }

    private func analyzeImageWithPromptAndProvider(
        _ image: NSImage,
        prompt: String,
        providerType: AIProviderType,
        isRetry: Bool,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        let apiKeys = orderedAPIKeysForRequest(providerType: providerType)

        guard !apiKeys.isEmpty else {
            if autoFallbackEnabled && !isRetry, let fallback = getNextFallbackProvider(after: providerType) {
                print("⚠️ No API key for \(providerType.rawValue), falling back to \(fallback.rawValue)")
                analyzeImageWithPromptAndProvider(image, prompt: prompt, providerType: fallback, isRetry: true, completion: completion)
                return
            }
            completion(.failure(.apiError("API Key for \(providerType.rawValue) not set. Please configure in Settings.")))
            return
        }
        
        let model = UserDefaults.standard.string(forKey: "selectedModel_\(providerType.rawValue)") ?? providerType.provider.defaultModel

        tryAnalyzeWithAPIKeyList(
            image,
            prompt: prompt,
            providerType: providerType,
            model: model,
            apiKeys: apiKeys,
            keyIndex: 0,
            isRetry: isRetry,
            completion: completion
        )
    }

    private func tryAnalyzeWithAPIKeyList(
        _ image: NSImage,
        prompt: String,
        providerType: AIProviderType,
        model: String,
        apiKeys: [String],
        keyIndex: Int,
        isRetry: Bool,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        let apiKey = apiKeys[keyIndex]

        providerType.provider.analyzeImage(
            image,
            apiKey: apiKey,
            model: model,
            prompt: prompt
        ) { [weak self] result in
            switch result {
            case .success:
                completion(result)

            case .failure(let error):
                let hasMoreKeys = keyIndex + 1 < apiKeys.count

                if hasMoreKeys {
                    print("⚠️ \(providerType.rawValue) key #\(keyIndex + 1) failed, retrying with next key")
                    self?.tryAnalyzeWithAPIKeyList(
                        image,
                        prompt: prompt,
                        providerType: providerType,
                        model: model,
                        apiKeys: apiKeys,
                        keyIndex: keyIndex + 1,
                        isRetry: isRetry,
                        completion: completion
                    )
                    return
                }

                // Try fallback provider after all keys of current provider fail
                if self?.autoFallbackEnabled == true && !isRetry,
                   let fallback = self?.getNextFallbackProvider(after: providerType) {
                    print("⚠️ \(providerType.rawValue) all keys failed: \(error.localizedDescription), falling back to \(fallback.rawValue)")
                    self?.analyzeImageWithPromptAndProvider(image, prompt: prompt, providerType: fallback, isRetry: true, completion: completion)
                    return
                }

                completion(.failure(error))
            }
        }
    }
}

// MARK: - Legacy API Service (for backward compatibility)

class APIService {
    static let shared = APIService()
    private init() {}
    
    func analyzeImage(_ image: NSImage, apiKey: String, mode: AnswerMode = .tracNghiem, expertContext: String? = nil, completion: @escaping (Result<String, APIError>) -> Void) {
        let provider = GeminiProvider()
        let prompt = mode.buildPrompt(expertContext: expertContext)
        provider.analyzeImage(image, apiKey: apiKey, model: provider.defaultModel, prompt: prompt, completion: completion)
    }
}

// MARK: - History Item

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let provider: String
    let model: String
    let mode: String
    let expertContext: String?
    let answer: String
    var isFavorite: Bool
    let imageData: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        provider: String,
        model: String,
        mode: String,
        expertContext: String?,
        answer: String,
        isFavorite: Bool = false,
        image: NSImage? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.provider = provider
        self.model = model
        self.mode = mode
        self.expertContext = expertContext
        self.answer = answer
        self.isFavorite = isFavorite
        self.imageData = image.flatMap { HistoryManager.compressImage($0) }
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var shortAnswer: String {
        answer.count <= 100 ? answer : String(answer.prefix(100)) + "..."
    }
}

// MARK: - History Manager

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    private let maxHistoryItems = 50
    private let userDefaultsKey = "visionkey_history"
    
    @Published var items: [HistoryItem] = []
    
    private init() {
        loadHistory()
    }
    
    func addItem(provider: String, model: String, mode: String, expertContext: String?, answer: String, image: NSImage?) {
        let item = HistoryItem(
            provider: provider, model: model, mode: mode,
            expertContext: expertContext, answer: answer, image: image
        )
        items.insert(item, at: 0)
        if items.count > maxHistoryItems {
            items = Array(items.prefix(maxHistoryItems))
        }
        saveHistory()
    }
    
    func toggleFavorite(_ item: HistoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite.toggle()
            saveHistory()
        }
    }
    
    func deleteItem(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearHistory(keepFavorites: Bool = true) {
        items = keepFavorites ? items.filter { $0.isFavorite } : []
        saveHistory()
    }
    
    var favorites: [HistoryItem] { items.filter { $0.isFavorite } }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        items = (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    static func compressImage(_ image: NSImage, maxSize: CGFloat = 150) -> String? {
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height)
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        
        guard let tiffData = newImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.4]) else { return nil }
        return jpegData.base64EncodedString()
    }
    
    static func imageFromBase64(_ base64: String) -> NSImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
    }
}

// MARK: - OCR Manager

import Vision

class OCRManager {
    static let shared = OCRManager()
    
    private init() {}
    
    /// Extract text from image using Vision framework
    func extractText(from image: NSImage, languages: [String] = ["vi-VN", "en-US"], completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot convert image"])))
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.success(""))
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(.success(recognizedText))
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Represents detected text with its bounding box
    struct TextObservation {
        let text: String
        let boundingBox: CGRect // Normalized coordinates (0-1)
    }
    
    /// Extract text with coordinates for auto-click feature
    func extractTextWithCoordinates(from image: NSImage, imageSize: CGSize, languages: [String] = ["vi-VN", "en-US"], completion: @escaping (Result<[TextObservation], Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot convert image"])))
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    completion(.success([]))
                }
                return
            }
            
            var textObservations: [TextObservation] = []
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    textObservations.append(TextObservation(
                        text: candidate.string,
                        boundingBox: observation.boundingBox
                    ))
                }
            }
            
            DispatchQueue.main.async {
                completion(.success(textObservations))
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Find screen coordinate of specific answer option (A, B, C, D)
    func findAnswerCoordinate(answer: String, in observations: [TextObservation], imageSize: CGSize, captureRect: CGRect) -> CGPoint? {
        let answerUpper = answer.uppercased()
        
        // Priority 1: Exact patterns like "A.", "A)", "A:", "A "
        let exactPatterns = ["\(answerUpper).", "\(answerUpper))", "\(answerUpper):", "\(answerUpper) "]
        
        for observation in observations {
            let text = observation.text.uppercased().trimmingCharacters(in: .whitespaces)
            
            for pattern in exactPatterns {
                if text.hasPrefix(pattern) || text == answerUpper {
                    return convertToScreenCoordinate(observation, imageSize: imageSize, captureRect: captureRect)
                }
            }
        }
        
        // Priority 2: Contains "Đáp án A" or "Answer A" or just standalone letter
        for observation in observations {
            let text = observation.text.uppercased()
            
            // Check for "Đáp án A", "Chọn A", etc.
            if text.contains("ĐÁP ÁN \(answerUpper)") || 
               text.contains("CHỌN \(answerUpper)") ||
               text.contains("ANSWER \(answerUpper)") {
                return convertToScreenCoordinate(observation, imageSize: imageSize, captureRect: captureRect)
            }
            
            // Standalone letter at start
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(answerUpper) && (trimmed.count == 1 || 
               (trimmed.count >= 2 && ".):]".contains(trimmed[trimmed.index(after: trimmed.startIndex)]))) {
                return convertToScreenCoordinate(observation, imageSize: imageSize, captureRect: captureRect)
            }
        }
        
        // Priority 3: Radio button or checkbox with answer
        for observation in observations {
            let text = observation.text.uppercased()
            // Patterns like "○ A", "● A", "□ A", "■ A"
            if text.contains("○ \(answerUpper)") || text.contains("● \(answerUpper)") ||
               text.contains("□ \(answerUpper)") || text.contains("■ \(answerUpper)") ||
               text.contains("◯ \(answerUpper)") || text.contains("◉ \(answerUpper)") {
                return convertToScreenCoordinate(observation, imageSize: imageSize, captureRect: captureRect)
            }
        }
        
        return nil
    }
    
    private func convertToScreenCoordinate(_ observation: TextObservation, imageSize: CGSize, captureRect: CGRect) -> CGPoint {
        // Vision uses bottom-left origin, we need to flip Y
        let normalizedX = observation.boundingBox.midX
        let normalizedY = 1.0 - observation.boundingBox.midY // Flip Y
        
        // Convert to image coordinates
        let imageX = normalizedX * imageSize.width
        let imageY = normalizedY * imageSize.height
        
        // Convert to screen coordinates
        let screenX = captureRect.origin.x + imageX
        let screenY = captureRect.origin.y + imageY
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    /// Check if OCR is available
    var isAvailable: Bool {
        if #available(macOS 10.15, *) {
            return true
        }
        return false
    }
}

// MARK: - Voice Input Manager

import Speech
import AVFoundation

class VoiceInputManager: NSObject, ObservableObject {
    static let shared = VoiceInputManager()
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    
    private override init() {
        super.init()
        // Default to Vietnamese, can be changed
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
    }
    
    var currentLanguage: String = "vi-VN" {
        didSet {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage))
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(true)
                default:
                    self.errorMessage = "Speech recognition not authorized"
                    completion(false)
                }
            }
        }
    }
    
    func startRecording(completion: @escaping (Result<String, Error>) -> Void) {
        // Check authorization
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            requestPermission { [weak self] authorized in
                if authorized {
                    self?.startRecording(completion: completion)
                } else {
                    completion(.failure(NSError(domain: "Voice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized. Grant permission in System Preferences > Privacy > Speech Recognition."])))
                }
            }
            return
        }
        
        // Stop any existing recording
        stopRecording()
        
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            completion(.failure(NSError(domain: "Voice", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])))
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            completion(.failure(NSError(domain: "Voice", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"])))
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            transcribedText = ""
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self?.stopRecording()
                        completion(.success(result.bestTranscription.formattedString))
                    }
                }
                
                if let error = error {
                    self?.stopRecording()
                    // Don't report cancellation as error
                    if (error as NSError).code != 1 { // Cancellation code
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            stopRecording()
            completion(.failure(error))
        }
    }
    
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
    
    /// Finish recording and get final text
    func finishRecording(completion: @escaping (String?) -> Void) {
        let text = transcribedText.isEmpty ? nil : transcribedText
        stopRecording()
        completion(text)
    }
}
