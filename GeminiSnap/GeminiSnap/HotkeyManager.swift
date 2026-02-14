//
//  HotkeyManager.swift
//  GeminiSnap
//
//  Global hotkey registration using Carbon APIs
//  Supports multiple hotkeys for different capture modes
//

import Carbon
import AppKit

enum CaptureMode {
    case region       // ⌘ + ⇧ + . (Period) - Select region
    case fullscreen   // ⌘ + ⇧ + , (Comma) - Full screen
    case voice        // ⌘ + ⇧ + / (Slash) - Voice input
    case instantQuiz  // ⌘ + ⇧ + M - Instant Quiz (fullscreen + fastest model + auto-click)
}

class HotkeyManager {
    private var regionHotKeyRef: EventHotKeyRef?
    private var fullscreenHotKeyRef: EventHotKeyRef?
    private var voiceHotKeyRef: EventHotKeyRef?
    private var instantQuizHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private var regionCallback: (() -> Void)?
    private var fullscreenCallback: (() -> Void)?
    private var voiceCallback: (() -> Void)?
    private var instantQuizCallback: (() -> Void)?
    
    // Static reference for the C callback
    private static var sharedInstance: HotkeyManager?
    
    init(regionCallback: @escaping () -> Void, fullscreenCallback: @escaping () -> Void, voiceCallback: (() -> Void)? = nil, instantQuizCallback: (() -> Void)? = nil) {
        self.regionCallback = regionCallback
        self.fullscreenCallback = fullscreenCallback
        self.voiceCallback = voiceCallback
        self.instantQuizCallback = instantQuizCallback
        HotkeyManager.sharedInstance = self
        registerHotkeys()
    }
    
    // Legacy init for backward compatibility
    convenience init(callback: @escaping () -> Void) {
        self.init(regionCallback: callback, fullscreenCallback: callback, voiceCallback: nil)
    }
    
    private func registerHotkeys() {
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        
        // Install event handler first (shared for all hotkeys)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                // Get the hotkey ID from the event
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                // Call appropriate callback based on hotkey ID
                switch hotKeyID.id {
                case 1:
                    HotkeyManager.sharedInstance?.handleRegionCapture()
                case 2:
                    HotkeyManager.sharedInstance?.handleFullscreenCapture()
                case 3:
                    HotkeyManager.sharedInstance?.handleVoiceInput()
                case 4:
                    HotkeyManager.sharedInstance?.handleInstantQuiz()
                default:
                    break
                }
                
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
        
        // Register Region Capture: ⌘ + ⇧ + . (Period, keycode 47)
        var regionHotKeyID = EventHotKeyID()
        regionHotKeyID.signature = OSType(0x47534E50) // "GSNP"
        regionHotKeyID.id = 1
        
        let regionStatus = RegisterEventHotKey(
            47, // Period key
            modifiers,
            regionHotKeyID,
            GetApplicationEventTarget(),
            0,
            &regionHotKeyRef
        )
        
        if regionStatus == noErr {
            print("✅ Global hotkey registered: ⌘ + ⇧ + . (Region Capture)")
        } else {
            print("❌ Failed to register region hotkey: \(regionStatus)")
        }
        
        // Register Fullscreen Capture: ⌘ + ⇧ + , (Comma, keycode 43)
        var fullscreenHotKeyID = EventHotKeyID()
        fullscreenHotKeyID.signature = OSType(0x47534E50) // "GSNP"
        fullscreenHotKeyID.id = 2
        
        let fullscreenStatus = RegisterEventHotKey(
            43, // Comma key
            modifiers,
            fullscreenHotKeyID,
            GetApplicationEventTarget(),
            0,
            &fullscreenHotKeyRef
        )
        
        if fullscreenStatus == noErr {
            print("✅ Global hotkey registered: ⌘ + ⇧ + , (Fullscreen Capture)")
        } else {
            print("❌ Failed to register fullscreen hotkey: \(fullscreenStatus)")
        }
        
        // Register Voice Input: ⌘ + ⇧ + / (Slash, keycode 44)
        var voiceHotKeyID = EventHotKeyID()
        voiceHotKeyID.signature = OSType(0x47534E50) // "GSNP"
        voiceHotKeyID.id = 3
        
        let voiceStatus = RegisterEventHotKey(
            44, // Slash key
            modifiers,
            voiceHotKeyID,
            GetApplicationEventTarget(),
            0,
            &voiceHotKeyRef
        )
        
        if voiceStatus == noErr {
            print("✅ Global hotkey registered: ⌘ + ⇧ + / (Voice Input)")
        } else {
            print("❌ Failed to register voice hotkey: \(voiceStatus)")
        }
        
        // Register Instant Quiz: ⌘ + ⇧ + M (M key, keycode 46)
        var instantQuizHotKeyID = EventHotKeyID()
        instantQuizHotKeyID.signature = OSType(0x47534E50) // "GSNP"
        instantQuizHotKeyID.id = 4
        
        let instantQuizStatus = RegisterEventHotKey(
            46, // M key
            modifiers,
            instantQuizHotKeyID,
            GetApplicationEventTarget(),
            0,
            &instantQuizHotKeyRef
        )
        
        if instantQuizStatus == noErr {
            print("✅ Global hotkey registered: ⌘ + ⇧ + M (Instant Quiz)")
        } else {
            print("❌ Failed to register instant quiz hotkey: \(instantQuizStatus)")
        }
    }
    
    private func handleRegionCapture() {
        DispatchQueue.main.async { [weak self] in
            self?.regionCallback?()
        }
    }
    
    private func handleFullscreenCapture() {
        DispatchQueue.main.async { [weak self] in
            self?.fullscreenCallback?()
        }
    }
    
    private func handleVoiceInput() {
        DispatchQueue.main.async { [weak self] in
            self?.voiceCallback?()
        }
    }
    
    private func handleInstantQuiz() {
        DispatchQueue.main.async { [weak self] in
            self?.instantQuizCallback?()
        }
    }
    
    func unregisterHotkey() {
        if let hotKeyRef = regionHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.regionHotKeyRef = nil
        }
        
        if let hotKeyRef = fullscreenHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.fullscreenHotKeyRef = nil
        }
        
        if let hotKeyRef = voiceHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.voiceHotKeyRef = nil
        }
        
        if let hotKeyRef = instantQuizHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.instantQuizHotKeyRef = nil
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
