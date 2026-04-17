//
//  KnowledgeBaseView.swift
//  Vision Key
//
//  UI for managing knowledge base documents
//  Upload, toggle, preview, and delete documents used as AI context
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
//

import SwiftUI

struct KnowledgeBaseView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var manager = KnowledgeBaseManager.shared
    @State private var showFileImporter = false
    @State private var errorMessage: String?
    @State private var previewDocument: KnowledgeDocument?
    @State private var showPreview = false
    @State private var dragOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if manager.documents.isEmpty {
                emptyStateView
            } else {
                documentListView
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(width: 420, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showPreview) {
            if let doc = previewDocument {
                documentPreviewSheet(doc)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Knowledge Base")
                        .font(.headline)
                    Text("Tài liệu tham khảo cho AI")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Toggle KB on/off
            Toggle("", isOn: $manager.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(manager.isEnabled ? "Tắt Knowledge Base" : "Bật Knowledge Base")
            
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Chưa có tài liệu nào")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Upload tài liệu (.txt, .md, .pdf, .csv, .json)\nđể AI sử dụng làm ngữ cảnh khi trả lời")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            
            Button(action: openFilePicker) {
                Label("Upload Tài Liệu", systemImage: "plus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dragOver ? Color.accentColor : Color.clear, lineWidth: 2)
                .background(dragOver ? Color.accentColor.opacity(0.05) : Color.clear)
                .cornerRadius(12)
                .padding(8)
        )
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    // MARK: - Document List
    
    private var documentListView: some View {
        VStack(spacing: 0) {
            // Stats bar
            HStack(spacing: 12) {
                Label("\(manager.activeDocuments.count)/\(manager.documents.count) active", systemImage: "doc.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                    Text("~\(formatTokens(manager.totalEstimatedTokens)) tokens")
                        .font(.caption)
                }
                .foregroundColor(manager.totalEstimatedTokens > 30000 ? .orange : .secondary)
                .help("Ước tính tokens dùng cho context")
                
                Button(action: openFilePicker) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .help("Thêm tài liệu")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
            
            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button(action: { errorMessage = nil }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
            }
            
            // Document list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(manager.documents) { doc in
                        documentRow(doc)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
    }
    
    // MARK: - Document Row
    
    private func documentRow(_ doc: KnowledgeDocument) -> some View {
        HStack(spacing: 10) {
            // File type icon
            fileTypeIcon(doc.fileType)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(doc.displaySize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("~\(formatTokens(doc.estimatedTokens))t")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(doc.displayDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 6) {
                // Preview
                Button(action: {
                    previewDocument = doc
                    showPreview = true
                }) {
                    Image(systemName: "eye")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Xem nội dung")
                
                // Toggle active
                Toggle("", isOn: Binding(
                    get: { doc.isActive },
                    set: { _ in manager.toggleDocument(doc.id) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(doc.isActive ? "Tắt tài liệu" : "Bật tài liệu")
                
                // Delete
                Button(action: {
                    withAnimation {
                        manager.removeDocument(doc.id)
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Xóa tài liệu")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(doc.isActive ? Color.accentColor.opacity(0.05) : Color.clear)
        .opacity(doc.isActive ? 1 : 0.6)
    }
    
    // MARK: - File Type Icon
    
    private func fileTypeIcon(_ type: KnowledgeFileType) -> some View {
        let color: Color = {
            switch type {
            case .txt: return .blue
            case .md: return .purple
            case .pdf: return .red
            case .csv: return .green
            case .json: return .orange
            case .custom: return .gray
            }
        }()
        
        return Image(systemName: type.icon)
            .font(.system(size: 14))
            .foregroundColor(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.1))
            .cornerRadius(6)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Text("Hỗ trợ: .txt, .md, .pdf, .csv, .json")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !manager.documents.isEmpty {
                Button("Xóa tất cả") {
                    manager.clearAll()
                }
                .font(.caption)
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Preview Sheet
    
    private func documentPreviewSheet(_ doc: KnowledgeDocument) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                fileTypeIcon(doc.fileType)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(doc.name)
                        .font(.headline)
                    Text("\(doc.displaySize) • ~\(formatTokens(doc.estimatedTokens)) tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showPreview = false }) {
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
                Text(doc.content)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 500, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func openFilePicker() {
        // NSOpenPanel phải chạy trên main thread
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [
                .plainText, .pdf, .json, .commaSeparatedText,
                .init(filenameExtension: "md")!
            ]
            panel.message = "Chọn tài liệu để thêm vào Knowledge Base"
            panel.prompt = "Thêm"
            // Đưa panel lên trên tất cả window (bao gồm NSPanel/popover)
            panel.level = .floating
            
            // runModal() đảm bảo panel hiện đúng dù được gọi từ NSPanel/floating window
            let response = panel.runModal()
            guard response == .OK else { return }
            
            let selectedURLs = panel.urls
            // Cập nhật UI state phải ở main thread
            DispatchQueue.main.async {
                for url in selectedURLs {
                    do {
                        try self.manager.addDocument(from: url)
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                DispatchQueue.main.async {
                    do {
                        try self.manager.addDocument(from: url)
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatTokens(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
    }
}

// MARK: - Knowledge Base Window Controller

class KnowledgeBaseWindowController {
    static let shared = KnowledgeBaseWindowController()
    private var window: NSWindow?
    
    private init() {}
    
    func showKnowledgeBase() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = KnowledgeBaseView(isPresented: .constant(true))
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Knowledge Base"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

#Preview {
    KnowledgeBaseView(isPresented: .constant(true))
}
