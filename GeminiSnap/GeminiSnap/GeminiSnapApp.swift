//
//  GeminiSnapApp.swift
//  GeminiSnap
//
//  AI Screen Assistant - Menu Bar Application
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
        
        // Initialize global hotkey (Cmd + Shift + .)
        hotkeyManager = HotkeyManager { [weak self] in
            self?.menuBarManager?.triggerScreenCapture()
        }
        
        // Hide dock icon (backup - also set via LSUIElement in Info.plist)
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterHotkey()
    }
}
