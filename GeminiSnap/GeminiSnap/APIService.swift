//
//  APIService.swift
//  GeminiSnap
//
//  Handles Gemini API calls via REST
//

import Foundation
import AppKit

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

// Chế độ trả lời
enum AnswerMode: String, CaseIterable {
    case tracNghiem = "Trắc nghiệm"
    case tuLuan = "Tự luận"
    
    var icon: String {
        switch self {
        case .tracNghiem: return "checkmark.circle.fill"
        case .tuLuan: return "text.alignleft"
        }
    }
    
    func buildPrompt(expertContext: String?) -> String {
        let expertLine = if let expert = expertContext, !expert.isEmpty {
            "Bạn là chuyên gia \(expert). "
        } else {
            ""
        }
        
        switch self {
        case .tracNghiem:
            return """
            \(expertLine)Trả lời bằng tiếng Việt.
            
            Bạn có thể giải thích ngắn gọn nếu cần, nhưng LUÔN LUÔN kết thúc bằng:
            
            FINAL_ANSWER: [đáp án cuối cùng]
            
            Ví dụ:
            - Bài toán: FINAL_ANSWER: 42
            - Trắc nghiệm: FINAL_ANSWER: C
            - Code: FINAL_ANSWER: ```code đã sửa```
            - Câu hỏi: FINAL_ANSWER: [câu trả lời ngắn]
            """
        case .tuLuan:
            return """
            \(expertLine)Trả lời bằng tiếng Việt. Giải thích RÕ RÀNG và CHI TIẾT.
            
            - Bài toán: giải từng bước, giải thích công thức
            - Code: giải thích lỗi, tại sao sai, cách sửa
            - Câu hỏi: trả lời đầy đủ với ví dụ nếu cần
            - Văn bản: phân tích và tóm tắt ý chính
            
            Cuối cùng, LUÔN LUÔN tóm tắt bằng:
            
            FINAL_ANSWER: [kết luận/đáp án cuối cùng]
            """
        }
    }
}

class APIService {
    static let shared = APIService()
    
    // Gemini 2.5 Pro - model mới nhất và mạnh nhất (June 2025)
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
    
    private init() {}
    
    func analyzeImage(_ image: NSImage, apiKey: String, mode: AnswerMode = .tracNghiem, expertContext: String? = nil, completion: @escaping (Result<String, APIError>) -> Void) {
        // Convert image to base64
        guard let imageData = imageToBase64(image) else {
            completion(.failure(.invalidImage))
            return
        }
        
        // Build URL
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            completion(.failure(.invalidURL))
            return
        }
        
        // Build request body with mode-specific prompt and expert context
        let prompt = mode.buildPrompt(expertContext: expertContext)
        let requestBody = buildRequestBody(imageBase64: imageData, prompt: prompt)
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.networkError(error)))
            return
        }
        
        // Make request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for error
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        completion(.failure(.apiError(message)))
                        return
                    }
                    
                    // Extract text from response
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
        }.resume()
    }
    
    private func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }
    
    private func buildRequestBody(imageBase64: String, prompt: String) -> [String: Any] {
        return [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": imageBase64
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.0,  // Deterministic output for accuracy
                "topK": 1,
                "topP": 1,
                "maxOutputTokens": 4096
            ]
        ]
    }
}
