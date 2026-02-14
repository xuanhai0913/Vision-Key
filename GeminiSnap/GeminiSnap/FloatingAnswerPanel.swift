//
//  FloatingAnswerPanel.swift
//  Vision Key
//
//  Floating popup to display AI answer quickly without opening the main popover
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
//

import SwiftUI
import AppKit

class FloatingAnswerPanel: NSObject {
    static let shared = FloatingAnswerPanel()
    
    private var panel: NSPanel?
    private var dismissTimer: Timer?
    private var onTap: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    /// Show the floating answer popup
    /// - Parameters:
    ///   - answer: The AI answer text to display
    ///   - autoDismissAfter: Seconds before auto-dismiss (0 = no auto-dismiss)
    ///   - onTap: Callback when user taps the popup
    func show(answer: String, autoDismissAfter: TimeInterval = 10, onTap: @escaping () -> Void) {
        // Dismiss any existing panel
        dismiss()
        
        self.onTap = onTap
        
        // Create the panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        
        // Create SwiftUI content
        let contentView = FloatingAnswerView(
            answer: answer,
            onTap: { [weak self] in
                self?.handleTap()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        
        // Position panel at top-right corner
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let x = screenFrame.maxX - panelFrame.width - 20
            let y = screenFrame.maxY - panelFrame.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Show with animation
        panel.alphaValue = 0
        panel.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1
        }
        
        self.panel = panel
        
        // Setup auto-dismiss timer
        if autoDismissAfter > 0 {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissAfter, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }
    
    /// Dismiss the floating panel with animation
    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        guard let panel = panel else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
        })
    }
    
    private func handleTap() {
        dismiss()
        onTap?()
    }
}

// MARK: - SwiftUI View

struct FloatingAnswerView: View {
    let answer: String
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    @State private var showCopied = false
    
    // Parse answers like "2:B 3:A,C,D 4:E" or simple "B" or "A,C"
    private var parsedAnswers: [(question: String, answers: [String])] {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for multi-question format: "2:B 3:A,C,D 4:E"
        // Supports A-G options and comma-separated multi-answers
        let pattern = #"(\d+):([A-Ga-g](?:,[A-Ga-g])*)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
            if !matches.isEmpty {
                return matches.compactMap { match in
                    guard match.numberOfRanges >= 3,
                          let qRange = Range(match.range(at: 1), in: trimmed),
                          let aRange = Range(match.range(at: 2), in: trimmed) else { return nil }
                    let answersStr = String(trimmed[aRange]).uppercased()
                    let answerList = answersStr.split(separator: ",").map { String($0) }
                    return (String(trimmed[qRange]), answerList)
                }
            }
        }
        
        // Simple answers: "B" or "A,C,D" or "B ✓ Clicked!"
        let cleaned = trimmed.replacingOccurrences(of: " ✓ Clicked!", with: "")
                             .replacingOccurrences(of: " (OCR không tìm thấy)", with: "")
        
        // Check for comma-separated: "A,C,D"
        if cleaned.contains(",") {
            let parts = cleaned.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).uppercased() }
            let validAnswers = parts.filter { "ABCDEFG".contains($0) && $0.count == 1 }
            if !validAnswers.isEmpty {
                return [("", validAnswers)]
            }
        }
        
        // Single letter: "B"
        let firstLetter = cleaned.prefix(1).uppercased()
        if "ABCDEFG".contains(firstLetter) && cleaned.count <= 2 {
            return [("", [firstLetter])]
        }
        
        // Fallback: show raw text
        return []
    }
    
    private var isClickedStatus: Bool {
        answer.contains("✓") || answer.contains("Clicked")
    }
    
    private var isErrorStatus: Bool {
        answer.contains("OCR") || answer.contains("không tìm")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with status
            HStack(spacing: 6) {
                Circle()
                    .fill(isErrorStatus ? Color.orange : (isClickedStatus ? Color.green : Color.blue))
                    .frame(width: 6, height: 6)
                
                Text(isClickedStatus ? "Đã click" : (isErrorStatus ? "Chờ click" : "Đáp án"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                if showCopied {
                    Text("Copied!")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            // Answer badges - supports multiple answers and wrapping
            if !parsedAnswers.isEmpty {
                // Use FlowLayout-like wrapping for many answers
                let allItems = parsedAnswers.flatMap { item -> [(q: String, a: String)] in
                    item.answers.map { (item.question, $0) }
                }
                
                // Simple wrap: show as horizontal scroll if too many
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 2) {
                                if !item.q.isEmpty {
                                    Text(item.q + ":")
                                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                Text(item.a)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(answerColor(for: item.a))
                            )
                        }
                    }
                }
                .frame(maxHeight: 30)
            } else {
                // Fallback: show raw text
                Text(answer)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isClickedStatus ? Color.green.opacity(0.5) : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // Copy on tap
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(answer, forType: .string)
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showCopied = false
            }
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
    
    private func answerColor(for letter: String) -> Color {
        switch letter {
        case "A": return Color(red: 0.2, green: 0.5, blue: 0.8) // Blue
        case "B": return Color(red: 0.3, green: 0.7, blue: 0.4) // Green
        case "C": return Color(red: 0.8, green: 0.5, blue: 0.2) // Orange
        case "D": return Color(red: 0.7, green: 0.3, blue: 0.5) // Purple
        case "E": return Color(red: 0.5, green: 0.7, blue: 0.8) // Cyan
        case "F": return Color(red: 0.8, green: 0.6, blue: 0.3) // Gold
        case "G": return Color(red: 0.6, green: 0.4, blue: 0.7) // Violet
        default: return Color.gray
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        FloatingAnswerView(
            answer: "2:B 3:C 4:A",
            onTap: {},
            onDismiss: {}
        )
        FloatingAnswerView(
            answer: "B ✓ Clicked!",
            onTap: {},
            onDismiss: {}
        )
        FloatingAnswerView(
            answer: "C (OCR không tìm thấy)",
            onTap: {},
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
