//
//  HotkeyManager.swift
//  GeminiSnap
//
//  Global hotkey registration using Carbon APIs
//

import Carbon
import AppKit

class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (() -> Void)?
    
    // Static reference for the C callback
    private static var sharedInstance: HotkeyManager?
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        HotkeyManager.sharedInstance = self
        registerHotkey()
    }
    
    private func registerHotkey() {
        // Cmd + Shift + . (Period)
        // Key code for '.' is 47
        // Modifiers: cmdKey = 256 (0x100), shiftKey = 512 (0x200)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 47 // Period key
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x47534E50) // "GSNP" - GeminiSNaP
        hotKeyID.id = 1
        
        // Register the hotkey
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // Install event handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                HotkeyManager.sharedInstance?.handleHotkey()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return
        }
        
        // Register the hotkey
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus != noErr {
            print("Failed to register hotkey: \(registerStatus)")
        } else {
            print("Global hotkey registered: Cmd + Shift + .")
        }
    }
    
    private func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.callback?()
        }
    }
    
    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        HotkeyManager.sharedInstance = nil
    }
    
    deinit {
        unregisterHotkey()
    }
}
