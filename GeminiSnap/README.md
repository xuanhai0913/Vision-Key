# GeminiSnap - AI Screen Assistant

A native macOS menu bar application that captures screen regions and analyzes them using Google's Gemini AI.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green)

## Features

- 🖥️ **Menu Bar App** - Lives in the macOS status bar, no dock icon
- 📸 **Screen Capture** - Drag to select any screen region
- 🤖 **AI Analysis** - Uses Google Gemini 1.5 Flash to analyze images
- ⌨️ **Global Hotkey** - Trigger capture with `Cmd + Shift + .`
- 📝 **Markdown Rendering** - Beautifully formatted AI responses
- 🔒 **Secure Storage** - API key stored in macOS Keychain

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Google Gemini API Key ([Get one here](https://aistudio.google.com/app/apikey))

## Installation

### Build from Source

1. **Clone the repository:**
   ```bash
   cd /Users/nguyenhai/Documents/GitHub/Vision-Key
   ```

2. **Open in Xcode:**
   ```bash
   open GeminiSnap/GeminiSnap.xcodeproj
   ```

3. **Build and Run:**
   - Press `Cmd + R` to build and run
   - Or use `Product > Run` from the menu

4. **Grant Permissions:**
   - On first launch, you'll be prompted for **Screen Recording** permission
   - Go to `System Settings > Privacy & Security > Screen Recording` and enable GeminiSnap

## Usage

### Setting Up Your API Key

1. Click the GeminiSnap icon (👁) in the menu bar
2. Click the gear icon (⚙️) or the "No API Key" indicator
3. Paste your Gemini API Key
4. Click "Save"

### Capturing Screen

**Method 1: Global Hotkey**
- Press `Cmd + Shift + .` from anywhere
- Drag to select a screen region
- Release to capture

**Method 2: Menu Bar**
- Click the GeminiSnap icon
- Click "Capture Screen" button
- Drag to select a screen region

### Viewing Results

- The AI response appears in the popover
- Use the **Copy** button to copy the response
- Click **New Capture** for another screenshot
- Click **Clear** to reset

## Development

### Setting API Key via Environment Variable

For development, you can set the API key in your Xcode scheme:

1. Open `Product > Scheme > Edit Scheme...`
2. Select `Run` > `Arguments`
3. Add Environment Variable:
   - Name: `GEMINI_API_KEY`
   - Value: `your-api-key-here`

### Project Structure

```
GeminiSnap/
├── GeminiSnap.xcodeproj/
├── GeminiSnap/
│   ├── GeminiSnapApp.swift      # App entry point
│   ├── ContentView.swift        # Main popover content
│   ├── MenuBarManager.swift     # Status bar management
│   ├── ScreenCaptureManager.swift # Screen capture logic
│   ├── HotkeyManager.swift      # Global hotkey (Cmd+Shift+.)
│   ├── APIService.swift         # Gemini REST API client
│   ├── KeychainHelper.swift     # Secure API key storage
│   ├── SettingsView.swift       # Settings UI
│   ├── ResultView.swift         # AI response display
│   ├── Assets.xcassets/         # App icons
│   ├── Info.plist               # App configuration
│   └── GeminiSnap.entitlements  # App capabilities
└── README.md
```

### Key Technologies

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Menu Bar | AppKit (NSStatusItem) |
| Screen Capture | CoreGraphics (CGWindowListCreateImage) |
| Global Hotkey | Carbon (RegisterEventHotKey) |
| API Calls | URLSession (REST) |
| Secure Storage | Security Framework (Keychain) |
| Markdown | AttributedString |

## API Reference

### Gemini API Endpoint

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_KEY
```

### Request Format

```json
{
  "contents": [{
    "parts": [
      { "text": "Analyze this image..." },
      { "inline_data": { "mime_type": "image/jpeg", "data": "BASE64_IMAGE" } }
    ]
  }],
  "generationConfig": {
    "temperature": 0.4,
    "maxOutputTokens": 4096
  }
}
```

## Troubleshooting

### Screen Capture Not Working

1. Check `System Settings > Privacy & Security > Screen Recording`
2. Ensure GeminiSnap is enabled
3. Restart the app after granting permission

### Global Hotkey Not Working

- The hotkey `Cmd + Shift + .` may conflict with other apps
- Check that no other app is using this shortcut
- Restart GeminiSnap

### API Errors

| Error | Solution |
|-------|----------|
| "Invalid API Key" | Verify your key in Settings |
| "Network error" | Check internet connection |
| "No content" | Try a different image |

## License

MIT License - See LICENSE file for details.

## Credits

- Google Gemini API for AI analysis
- Apple's SwiftUI and AppKit frameworks
