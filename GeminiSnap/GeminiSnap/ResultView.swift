//
//  ResultView.swift
//  GeminiSnap
//
//  Displays the AI analysis result with Markdown rendering
//

import SwiftUI
import AppKit

struct ResultView: View {
    let image: NSImage?
    let resultText: String?
    let errorMessage: String?
    let isLoading: Bool
    let onCopy: () -> Void
    let onNewCapture: () -> Void
    let onClear: () -> Void
    
    @State private var showCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Image preview
            if let image = image {
                imagePreviewSection(image: image)
            }
            
            Divider()
            
            // Result section
            resultSection
        }
    }
    
    // MARK: - Image Preview
    
    private func imagePreviewSection(image: NSImage) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Captured Image")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 120)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .background(Color.secondary.opacity(0.05))
    }
    
    // MARK: - Result Section
    
    @ViewBuilder
    private var resultSection: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(message: error)
        } else if let result = resultText {
            successView(text: result)
        } else {
            emptyView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Analyzing image...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                onNewCapture()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func successView(text: String) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("AI Response")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Copy button
                Button(action: {
                    copyToClipboard(text)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied!" : "Copy")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
            
            // Markdown content
            ScrollView {
                MarkdownTextView(text: text)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Button(action: onClear) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button(action: onNewCapture) {
                    Label("New Capture", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Ready to Capture")
                .font(.headline)
            
            Text("Press ⌘ + ⇧ + . or click 'Capture' below")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: onNewCapture) {
                Label("Capture Screen", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helpers
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
        
        onCopy()
    }
}

// MARK: - Markdown Text View

struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        // Using native SwiftUI Text with AttributedString for Markdown
        // This supports basic Markdown (bold, italic, code, links)
        if let attributed = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.system(.body, design: .default))
                .textSelection(.enabled)
                .lineSpacing(4)
        } else {
            // Fallback to plain text
            Text(text)
                .font(.system(.body, design: .default))
                .textSelection(.enabled)
                .lineSpacing(4)
        }
    }
}

// MARK: - Preview

#Preview("Loading") {
    ResultView(
        image: nil,
        resultText: nil,
        errorMessage: nil,
        isLoading: true,
        onCopy: {},
        onNewCapture: {},
        onClear: {}
    )
    .frame(width: 400, height: 500)
}

#Preview("Success") {
    ResultView(
        image: nil,
        resultText: """
        # Analysis Result
        
        This is a **test** response with some `code` and *italic* text.
        
        Here's a list:
        - Item 1
        - Item 2
        - Item 3
        
        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        """,
        errorMessage: nil,
        isLoading: false,
        onCopy: {},
        onNewCapture: {},
        onClear: {}
    )
    .frame(width: 400, height: 500)
}

#Preview("Error") {
    ResultView(
        image: nil,
        resultText: nil,
        errorMessage: "Invalid API Key. Please check your settings.",
        isLoading: false,
        onCopy: {},
        onNewCapture: {},
        onClear: {}
    )
    .frame(width: 400, height: 500)
}
