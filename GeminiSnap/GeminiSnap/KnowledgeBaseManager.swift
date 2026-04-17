//
//  KnowledgeBaseManager.swift
//  Vision Key
//
//  Knowledge Base system - Upload documents as AI context (like NotebookLM)
//  Replaces the old MIS Mode with a flexible document-based approach
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
//

import Foundation
import AppKit
import PDFKit

// MARK: - Knowledge Document Model

struct KnowledgeDocument: Identifiable, Codable {
    let id: UUID
    let name: String
    let fileType: KnowledgeFileType
    let content: String
    let addedDate: Date
    var isActive: Bool
    let fileSize: Int // bytes
    
    init(id: UUID = UUID(), name: String, fileType: KnowledgeFileType, content: String, addedDate: Date = Date(), isActive: Bool = true, fileSize: Int) {
        self.id = id
        self.name = name
        self.fileType = fileType
        self.content = content
        self.addedDate = addedDate
        self.isActive = isActive
        self.fileSize = fileSize
    }
    
    var displaySize: String {
        if fileSize < 1024 {
            return "\(fileSize) B"
        } else if fileSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(fileSize) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(fileSize) / (1024.0 * 1024.0))
        }
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: addedDate)
    }
    
    var contentPreview: String {
        let lines = content.components(separatedBy: "\n").prefix(5)
        let preview = lines.joined(separator: "\n")
        return preview.count <= 200 ? preview : String(preview.prefix(200)) + "..."
    }
    
    var estimatedTokens: Int {
        // Rough estimate: ~4 characters per token for Vietnamese/English mixed content
        return content.count / 4
    }
}

// MARK: - File Type

enum KnowledgeFileType: String, Codable, CaseIterable {
    case txt = "txt"
    case md = "md"
    case pdf = "pdf"
    case csv = "csv"
    case json = "json"
    case custom = "other"
    
    var icon: String {
        switch self {
        case .txt: return "doc.text"
        case .md: return "doc.richtext"
        case .pdf: return "doc.fill"
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .custom: return "doc"
        }
    }
    
    var color: String {
        switch self {
        case .txt: return "blue"
        case .md: return "purple"
        case .pdf: return "red"
        case .csv: return "green"
        case .json: return "orange"
        case .custom: return "gray"
        }
    }
    
    static func fromExtension(_ ext: String) -> KnowledgeFileType {
        switch ext.lowercased() {
        case "txt": return .txt
        case "md", "markdown": return .md
        case "pdf": return .pdf
        case "csv": return .csv
        case "json": return .json
        default: return .custom
        }
    }
    
    static var supportedExtensions: [String] {
        return ["txt", "md", "markdown", "pdf", "csv", "json"]
    }
}

// MARK: - Knowledge Base Errors

enum KnowledgeBaseError: LocalizedError {
    case fileNotFound
    case unsupportedFormat(String)
    case contentExtractionFailed
    case fileTooLarge(Int)
    case documentLimitReached
    case totalSizeLimitReached
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File không tìm thấy"
        case .unsupportedFormat(let ext):
            return "Định dạng .\(ext) không được hỗ trợ. Hỗ trợ: .txt, .md, .pdf, .csv, .json"
        case .contentExtractionFailed:
            return "Không thể đọc nội dung file"
        case .fileTooLarge(let size):
            return "File quá lớn (\(size / 1024)KB). Giới hạn: 2MB/file"
        case .documentLimitReached:
            return "Đã đạt giới hạn 20 tài liệu"
        case .totalSizeLimitReached:
            return "Tổng dung lượng vượt giới hạn 1MB text"
        }
    }
}

// MARK: - Knowledge Base Manager

class KnowledgeBaseManager: ObservableObject {
    static let shared = KnowledgeBaseManager()
    
    @Published var documents: [KnowledgeDocument] = []
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "knowledgeBaseEnabled")
        }
    }
    @Published var lastError: String?
    
    private let maxDocuments = 20
    private let maxFileSize = 2 * 1024 * 1024   // 2MB per file
    private let maxTotalTextSize = 1024 * 1024  // 1MB total text (~250K tokens)
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("VisionKey/knowledge")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var metadataURL: URL {
        storageURL.appendingPathComponent("metadata.json")
    }
    
    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "knowledgeBaseEnabled")
        loadDocuments()
    }
    
    // MARK: - Active Documents
    
    var activeDocuments: [KnowledgeDocument] {
        documents.filter { $0.isActive }
    }
    
    var totalActiveTextSize: Int {
        activeDocuments.reduce(0) { $0 + $1.content.count }
    }
    
    var totalEstimatedTokens: Int {
        activeDocuments.reduce(0) { $0 + $1.estimatedTokens }
    }
    
    // MARK: - CRUD Operations
    
    /// Add a document from a file URL
    func addDocument(from url: URL) throws {
        // Check document limit
        guard documents.count < maxDocuments else {
            throw KnowledgeBaseError.documentLimitReached
        }
        
        // Check file exists and get attributes
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw KnowledgeBaseError.fileNotFound
        }
        
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? Int ?? 0
        
        guard fileSize <= maxFileSize else {
            throw KnowledgeBaseError.fileTooLarge(fileSize)
        }
        
        // Check file type
        let ext = url.pathExtension.lowercased()
        guard KnowledgeFileType.supportedExtensions.contains(ext) || ext.isEmpty else {
            throw KnowledgeBaseError.unsupportedFormat(ext)
        }
        
        // Extract content
        let content = try extractContent(from: url, fileType: KnowledgeFileType.fromExtension(ext))
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KnowledgeBaseError.contentExtractionFailed
        }
        
        // Check total size
        let currentTotal = documents.reduce(0) { $0 + $1.content.count }
        guard currentTotal + content.count <= maxTotalTextSize else {
            throw KnowledgeBaseError.totalSizeLimitReached
        }
        
        // Create document
        let document = KnowledgeDocument(
            name: url.lastPathComponent,
            fileType: KnowledgeFileType.fromExtension(ext),
            content: content,
            isActive: true,
            fileSize: fileSize
        )
        
        documents.append(document)
        saveDocuments()
        lastError = nil
        
        print("📚 Knowledge Base: Added '\(document.name)' (\(document.displaySize), ~\(document.estimatedTokens) tokens)")
    }
    
    /// Remove a document by ID
    func removeDocument(_ id: UUID) {
        documents.removeAll { $0.id == id }
        saveDocuments()
    }
    
    /// Toggle a document's active state
    func toggleDocument(_ id: UUID) {
        if let index = documents.firstIndex(where: { $0.id == id }) {
            documents[index].isActive.toggle()
            saveDocuments()
        }
    }
    
    /// Clear all documents
    func clearAll() {
        documents.removeAll()
        saveDocuments()
    }
    
    // MARK: - Content Extraction
    
    private func extractContent(from url: URL, fileType: KnowledgeFileType) throws -> String {
        switch fileType {
        case .txt, .md, .csv, .custom:
            return try extractTextContent(from: url)
        case .pdf:
            return try extractPDFContent(from: url)
        case .json:
            return try extractJSONContent(from: url)
        }
    }
    
    private func extractTextContent(from url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Try other encodings
            if let data = FileManager.default.contents(atPath: url.path) {
                if let text = String(data: data, encoding: .utf16) { return text }
                if let text = String(data: data, encoding: .ascii) { return text }
            }
            throw KnowledgeBaseError.contentExtractionFailed
        }
    }
    
    private func extractPDFContent(from url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw KnowledgeBaseError.contentExtractionFailed
        }
        
        var fullText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KnowledgeBaseError.contentExtractionFailed
        }
        
        return fullText
    }
    
    private func extractJSONContent(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        // Pretty-print JSON for readability
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        // Fallback to raw string
        return try extractTextContent(from: url)
    }
    
    // MARK: - Context Building
    
    /// Build the context prompt from active documents
    func buildContextPrompt() -> String {
        let active = activeDocuments
        guard !active.isEmpty else { return "" }
        
        var context = "📚 BỐI CẢNH TÀI LIỆU (Knowledge Base):\n"
        context += "Dưới đây là nội dung tài liệu tham khảo. Hãy sử dụng thông tin này để trả lời chính xác hơn.\n\n"
        
        for (index, doc) in active.enumerated() {
            context += "━━━ Tài liệu \(index + 1): \(doc.name) ━━━\n"
            context += doc.content
            context += "\n━━━ Kết thúc tài liệu \(index + 1) ━━━\n\n"
        }
        
        context += "Hãy dựa vào các tài liệu trên để trả lời. Nếu câu hỏi nằm ngoài tài liệu, hãy dùng kiến thức chung.\n\n"
        
        return context
    }
    
    // MARK: - Persistence
    
    func saveDocuments() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: metadataURL)
        } catch {
            print("❌ Knowledge Base: Failed to save: \(error)")
        }
    }
    
    func loadDocuments() {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }
        do {
            let data = try Data(contentsOf: metadataURL)
            documents = try JSONDecoder().decode([KnowledgeDocument].self, from: data)
            print("📚 Knowledge Base: Loaded \(documents.count) documents")
        } catch {
            print("❌ Knowledge Base: Failed to load: \(error)")
            documents = []
        }
    }
}

// MARK: - Notification Names Extension

extension Notification.Name {
    static let knowledgeBaseChanged = Notification.Name("knowledgeBaseChanged")
}
