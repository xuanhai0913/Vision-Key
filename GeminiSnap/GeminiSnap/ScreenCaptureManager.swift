//
//  ScreenCaptureManager.swift
//  GeminiSnap
//
//  Handles screen region selection and capture using macOS screencapture
//

import AppKit
import CoreGraphics

class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    
    /// Last capture region coordinates (for auto-click)
    var lastCaptureRect: CGRect = .zero
    
    private init() {}
    
    /// Capture a selected region of the screen (interactive mode)
    /// User can drag to select an area
    func captureScreen(completion: @escaping (NSImage?) -> Void) {
        // -i: interactive mode (select region)
        // -x: no sound
        runScreenCapture(arguments: ["-i", "-x"], completion: completion)
    }
    
    /// Capture a selected region and track coordinates
    /// Uses -R flag with screen dimensions to get the selection rect
    func captureScreenWithRect(completion: @escaping (NSImage?, CGRect) -> Void) {
        // Get main screen bounds
        guard let screen = NSScreen.main else {
            completion(nil, .zero)
            return
        }
        
        let screenRect = screen.frame
        
        // Use interactive capture with coordinate output
        let tempFile = NSTemporaryDirectory() + "geminisnap_\(UUID().uuidString).png"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i: interactive, -x: no sound, -r: no .png extension handling
        process.arguments = ["-i", "-x", tempFile]
        
        do {
            try process.run()
            
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    if FileManager.default.fileExists(atPath: tempFile) {
                        if let image = NSImage(contentsOfFile: tempFile) {
                            // Estimate capture rect based on image size and mouse position
                            // For now, use screen center as approximation
                            let imageSize = image.size
                            let captureRect = CGRect(
                                x: (screenRect.width - imageSize.width) / 2,
                                y: (screenRect.height - imageSize.height) / 2,
                                width: imageSize.width,
                                height: imageSize.height
                            )
                            self.lastCaptureRect = captureRect
                            
                            try? FileManager.default.removeItem(atPath: tempFile)
                            completion(image, captureRect)
                        } else {
                            try? FileManager.default.removeItem(atPath: tempFile)
                            completion(nil, .zero)
                        }
                    } else {
                        completion(nil, .zero)
                    }
                }
            }
        } catch {
            print("Failed to run screencapture: \(error)")
            completion(nil, .zero)
        }
    }
    
    /// Capture the entire screen (fullscreen mode)
    /// No user interaction required
    func captureFullScreen(completion: @escaping (NSImage?) -> Void) {
        // -x: no sound
        // No -i flag = capture entire screen immediately
        if let screen = NSScreen.main {
            lastCaptureRect = screen.frame
        }
        runScreenCapture(arguments: ["-x"], completion: completion)
    }
    
    /// Shared helper to run screencapture with given arguments
    private func runScreenCapture(arguments: [String], completion: @escaping (NSImage?) -> Void) {
        let tempFile = NSTemporaryDirectory() + "geminisnap_\(UUID().uuidString).png"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments + [tempFile]
        
        do {
            try process.run()
            
            // Wait for process to complete in background
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    // Check if file was created (user didn't cancel)
                    if FileManager.default.fileExists(atPath: tempFile) {
                        if let image = NSImage(contentsOfFile: tempFile) {
                            // Clean up temp file
                            try? FileManager.default.removeItem(atPath: tempFile)
                            completion(image)
                        } else {
                            try? FileManager.default.removeItem(atPath: tempFile)
                            completion(nil)
                        }
                    } else {
                        // User cancelled (pressed ESC)
                        completion(nil)
                    }
                }
            }
        } catch {
            print("Failed to run screencapture: \(error)")
            completion(nil)
        }
    }
}
