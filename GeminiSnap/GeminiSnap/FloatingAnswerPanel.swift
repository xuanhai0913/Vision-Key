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
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "eye.circle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Vision Key")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Answer content
            Text(answer)
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Hint
            Text("Click to expand • Auto-dismiss in 10s")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    FloatingAnswerView(
        answer: "Đáp án: C. Vì theo định lý Pythagoras...",
        onTap: {},
        onDismiss: {}
    )
    .padding()
}
