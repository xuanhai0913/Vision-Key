//
//  ContentView.swift
//  Vision Key
//
//  Copyright © 2025 Nguyễn Xuân Hải (xuanhai0913)
//  GitHub: https://github.com/xuanhai0913
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var menuBarManager: MenuBarManager
    @State private var showSettings = false
    @State private var showHistory = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Main content
            ResultView(
                image: menuBarManager.capturedImage,
                resultText: menuBarManager.resultText,
                errorMessage: menuBarManager.errorMessage,
                isLoading: menuBarManager.isLoading,
                onCopy: {
                    // Notification or haptic feedback could go here
                },
                onNewCapture: {
                    menuBarManager.triggerScreenCapture()
                },
                onClear: {
                    menuBarManager.clearResult()
                }
            )
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: showSettings) { newValue in
            if newValue {
                // Open Settings in separate window instead of sheet
                SettingsWindowController.shared.showSettings()
                showSettings = false // Reset immediately
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(isPresented: $showHistory, onSelect: { item in
                menuBarManager.resultText = item.answer
                showHistory = false
            })
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                // App icon and title
                HStack(spacing: 8) {
                    Image(systemName: "eye.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Vision Key")
                            .font(.headline)
                        Text("by xuanhai0913")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // API Key status indicator
                    apiKeyStatusIndicator
                    
                    // Settings button
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                    
                    // Menu
                    Menu {
                        Button(action: { menuBarManager.triggerScreenCapture() }) {
                            Label("Capture Screen", systemImage: "camera.viewfinder")
                        }
                        .keyboardShortcut(".", modifiers: [.command, .shift])
                        
                        Divider()
                        
                        Button(action: { showSettings = true }) {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .keyboardShortcut(",", modifiers: .command)
                        
                        Button(action: { showHistory = true }) {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                        .keyboardShortcut("h", modifiers: .command)
                        
                        Divider()
                        
                        Button(action: { menuBarManager.quit() }) {
                            Label("Quit GeminiSnap", systemImage: "power")
                        }
                        .keyboardShortcut("q", modifiers: .command)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            
            // Answer Mode Toggle
            answerModeToggle
            
            // Expert Context Input
            expertContextInput
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
    }
    
    // MARK: - Answer Mode Toggle
    
    private var answerModeToggle: some View {
        HStack(spacing: 8) {
            // Mode buttons
            HStack(spacing: 0) {
                ForEach(AnswerMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            menuBarManager.answerMode = mode
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.caption)
                            Text(mode.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            menuBarManager.answerMode == mode
                                ? Color.accentColor
                                : Color.clear
                        )
                        .foregroundColor(
                            menuBarManager.answerMode == mode
                                ? .white
                                : .secondary
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(8)
            
            // Language picker
            languagePicker
        }
    }
    
    private var languagePicker: some View {
        Menu {
            ForEach(ResponseLanguage.allCases) { lang in
                Button(action: {
                    AIServiceManager.shared.currentLanguage = lang
                }) {
                    HStack {
                        Text(lang.icon)
                        Text(lang.rawValue)
                        if AIServiceManager.shared.currentLanguage == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(AIServiceManager.shared.currentLanguage.icon)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Response language")
    }
    
    // MARK: - Expert Context Input
    
    private var expertContextInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill.questionmark")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("Chuyên gia gì? (VD: Toán, Python, Hóa học...)", text: $menuBarManager.expertContext)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - API Key Status
    
    @ViewBuilder
    private var apiKeyStatusIndicator: some View {
        let hasKey = KeychainHelper.hasAPIKey()
        
        Button(action: { showSettings = true }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(hasKey ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(hasKey ? "Ready" : "No API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .help(hasKey ? "API Key configured" : "Click to configure API Key")
    }
}

#Preview {
    ContentView(menuBarManager: MenuBarManager())
        .frame(width: 400, height: 500)
}

// MARK: - History View

struct HistoryView: View {
    @Binding var isPresented: Bool
    var onSelect: (HistoryItem) -> Void
    @ObservedObject private var historyManager = HistoryManager.shared
    @State private var showFavoritesOnly = false
    
    var filteredItems: [HistoryItem] {
        showFavoritesOnly ? historyManager.favorites : historyManager.items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.accentColor)
                Text("History")
                    .font(.headline)
                Spacer()
                
                Toggle(isOn: $showFavoritesOnly) {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // List
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: showFavoritesOnly ? "star.slash" : "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(showFavoritesOnly ? "No favorites yet" : "No history yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredItems) { item in
                        HistoryItemRow(item: item, onTap: {
                            onSelect(item)
                        }, onToggleFavorite: {
                            historyManager.toggleFavorite(item)
                        }, onDelete: {
                            historyManager.deleteItem(item)
                        })
                    }
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear All") {
                    historyManager.clearHistory(keepFavorites: true)
                }
                .font(.caption)
                .disabled(historyManager.items.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 380, height: 450)
    }
}

struct HistoryItemRow: View {
    let item: HistoryItem
    var onTap: () -> Void
    var onToggleFavorite: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Thumbnail
            if let imageData = item.imageData, let img = HistoryManager.imageFromBase64(imageData) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.provider)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(item.mode)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(item.displayDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(item.shortAnswer)
                    .font(.caption)
                    .lineLimit(2)
            }
            
            // Actions
            VStack(spacing: 4) {
                Button(action: onToggleFavorite) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .foregroundColor(item.isFavorite ? .yellow : .secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
