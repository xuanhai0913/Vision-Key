# Vision Key - AI Screen Assistant

<div align="center">

![Vision Key Logo](https://img.shields.io/badge/Vision_Key-AI_Screen_Assistant-purple?style=for-the-badge&logo=apple)

<a href="https://my-portfolio-nxh.vercel.app/">
  <img src="https://res.cloudinary.com/dqdcqtu8m/image/upload/v1765001214/Logo_st3nmr.png" width="90%" alt="Vision Key Logo" />
</a>

###  Cross-Platform Support:

| Platform | Status | Link / Repository |
|:--------:|:------:|:------------------|
|  **macOS (Native)** |  **Stable** | [**Vision-Key**](https://github.com/xuanhai0913/Vision-Key) <br> *(Current)* <br> [![Stars](https://img.shields.io/github/stars/xuanhai0913/Vision-Key?style=social)](https://github.com/xuanhai0913/Vision-Key) |
|  **Browser Extension** |  **Stable** | [**Chrome/Edge**](https://github.com/xuanhai0913/Extension-Vision-Key) <br> [![Ext Stars](https://img.shields.io/github/stars/xuanhai0913/Extension-Vision-Key?style=social)](https://github.com/xuanhai0913/Extension-Vision-Key) |
|  **Windows (Native)** | 🚧 **Dev** | *Coming soon...* |

---

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square&logo=swift)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![Gemini](https://img.shields.io/badge/Gemini_2.5_Pro-API-4285F4?style=flat-square&logo=google)](https://ai.google.dev/)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)



**Ứng dụng menu bar macOS tích hợp AI Gemini để phân tích ảnh chụp màn hình**



[Tính năng](#-tính-năng) • [Cài đặt](#-cài-đặt) • [Sử dụng](#-sử-dụng) • [Phát triển](#-phát-triển)

</div>

---

## ✨ Tính năng

| Tính năng | Mô tả |
|-----------|-------|
|  **Menu Bar App** | Chạy trên thanh menu, không chiếm dock |
| 📸 **Chụp màn hình** | Kéo chọn vùng bất kỳ trên màn hình |
| 🤖 **AI Gemini 2.5 Pro** | Phân tích ảnh với model AI mạnh nhất |
| ⌨️ **Phím tắt toàn cục** | \`⌘ + ⇧ + .\` để chụp từ bất kỳ đâu |
| 🎯 **2 chế độ trả lời** | Trắc nghiệm (chỉ đáp án) & Tự luận (giải thích chi tiết) |
|  **Vai trò chuyên gia** | Nhập lĩnh vực để AI trả lời chính xác hơn |
| 🇻🇳 **Tiếng Việt** | 100% hỗ trợ tiếng Việt |
| 🔒 **Bảo mật** | API key lưu trong macOS Keychain |

## 📋 Yêu cầu

- macOS 13.0 trở lên
- Xcode 15.0 trở lên
- Google Gemini API Key ([Lấy tại đây](https://aistudio.google.com/app/apikey))

## 🚀 Cài đặt

### Build từ Source

```bash
# Clone repository
git clone https://github.com/xuanhai0913/Vision-Key.git
cd Vision-Key

# Mở Xcode
open GeminiSnap/GeminiSnap.xcodeproj

# Build và Run (Cmd + R)
```

### Cấp quyền

Khi chạy lần đầu, cho phép **Screen Recording** tại:
\`System Settings > Privacy & Security > Screen Recording\`

## 📖 Sử dụng

### 1. Cài đặt API Key

1. Click icon 👁 trên menu bar
2. Vào Settings (⚙️)
3. Dán Gemini API Key
4. Click "Save"

### 2. Chụp màn hình

**Cách 1:** Nhấn \`⌘ + ⇧ + .\` → Kéo chọn vùng → Thả

**Cách 2:** Click icon → "Capture Screen" → Kéo chọn

### 3. Chọn chế độ

| Chế độ | Khi nào dùng |
|--------|--------------|
| **Trắc nghiệm** | Cần đáp án nhanh (A, B, C, D hoặc số) |
| **Tự luận** | Cần giải thích chi tiết từng bước |

### 4. Nhập vai chuyên gia (tùy chọn)

Nhập lĩnh vực để AI trả lời chính xác hơn:
- \`Toán học\` - cho bài toán
- \`Python\` - cho code Python
- \`Hóa học\` - cho bài Hóa
- \`IELTS\` - cho tiếng Anh

## 🛠️ Phát triển

### Cấu trúc Project

```
GeminiSnap/
├── GeminiSnapApp.swift      # Entry point
├── ContentView.swift        # Main UI
├── MenuBarManager.swift     # Status bar & logic
├── ScreenCaptureManager.swift # Chụp màn hình
├── HotkeyManager.swift      # Global hotkey (⌘⇧.)
├── APIService.swift         # Gemini REST API
├── KeychainHelper.swift     # Lưu API key an toàn
├── SettingsView.swift       # Cài đặt
└── ResultView.swift         # Hiển thị kết quả
```

### Công nghệ sử dụng

| Component | Technology |
|-----------|------------|
| UI | SwiftUI |
| Menu Bar | AppKit (NSStatusItem) |
| Screen Capture | macOS \`screencapture\` command |
| Global Hotkey | Carbon (RegisterEventHotKey) |
| API | URLSession + Gemini REST API |
| Storage | Security Framework (Keychain) |

### API Endpoint

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent
```

## ❓ Xử lý lỗi

| Lỗi | Giải pháp |
|-----|-----------|
| Không chụp được màn hình | Kiểm tra quyền Screen Recording |
| Phím tắt không hoạt động | Kiểm tra conflict với app khác |
| API Error | Kiểm tra API key trong Settings |

## 📄 License

MIT License - Xem file [LICENSE](LICENSE) để biết thêm chi tiết.

---

<div align="center">

## 👨‍💻 Tác giả
<div align="center">
  <a href="https://my-portfolio-nxh.vercel.app/">
    <img src="https://res.cloudinary.com/dqdcqtu8m/image/upload/v1765001229/Icon_y7wrcf.png" width="40%" alt="Vision Key Demo" />
  </a>
  
**Nguyễn Xuân Hải**

[![GitHub](https://img.shields.io/badge/GitHub-xuanhai0913-181717?style=for-the-badge&logo=github)](https://github.com/xuanhai0913)

---

**© 2025 Nguyễn Xuân Hải (xuanhai0913). All rights reserved.**

Made with ❤️ in Vietnam 🇻🇳

⭐ Nếu thấy hữu ích, hãy star repo này nhé!

</div>
