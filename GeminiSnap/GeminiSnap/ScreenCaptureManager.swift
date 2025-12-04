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
    
    private init() {}
    
    func captureScreen(completion: @escaping (NSImage?) -> Void) {
        // Use macOS built-in screencapture tool - most reliable method
        let tempFile = NSTemporaryDirectory() + "geminisnap_\(UUID().uuidString).png"
        
        // -i: interactive mode (select region)
        // -s: only allow selection (no window capture)
        // -x: no sound
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", tempFile]
        
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
