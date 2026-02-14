//
//  GeminiSnapApp.swift
//  Vision Key
//
//  AI Screen Assistant - Capture & Analyze with Gemini
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
//

import SwiftUI
import AppKit

@main
struct GeminiSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty Settings scene - we use menu bar only
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?
    var hotkeyManager: HotkeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the menu bar manager
        menuBarManager = MenuBarManager()
        
        // Initialize global hotkeys:
        // - ⌘ + ⇧ + . (Period) = Region capture
        // - ⌘ + ⇧ + , (Comma) = Fullscreen capture
        // - ⌘ + ⇧ + / (Slash) = Voice input
        // - ⌘ + ⇧ + N = Instant Quiz (fastest capture + auto-click)
        hotkeyManager = HotkeyManager(
            regionCallback: { [weak self] in
                self?.menuBarManager?.triggerScreenCapture()
            },
            fullscreenCallback: { [weak self] in
                self?.menuBarManager?.triggerFullscreenCapture()
            },
            voiceCallback: { [weak self] in
                self?.menuBarManager?.triggerVoiceInput()
            },
            instantQuizCallback: { [weak self] in
                self?.menuBarManager?.triggerInstantQuizCapture()
            }
        )
        
        // Hide dock icon (backup - also set via LSUIElement in Info.plist)
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterHotkey()
    }
}
