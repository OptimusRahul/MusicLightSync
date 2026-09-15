//
//  ContentView.swift
//  MusicLightSync
//
//  Created by Rahul Srivastava on 06/04/25.
//

import SwiftUI
import os.log

// MARK: - Modern ContentView with Component Architecture

struct ContentView: View {
    @EnvironmentObject private var bleManager: BLEManager
    @EnvironmentObject private var audioAnalyzer: AudioAnalyzer
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var isMusicSyncActive: Bool = false
    
    private let logger = Logger(subsystem: "com.musiclightsync.main", category: "ContentView")
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Header
                    HeaderView()
                    
                    // Device Connection Section
                    DeviceConnectionView()
                    
                    // Music Sensitivity Controls
                    MusicSensitivityView()
                    
                    // LED Controls
                    LEDControlsView()

                    // Music Sync Control
                    MusicSyncControlView(
                        isMusicSyncActive: $isMusicSyncActive,
                        onToggle: toggleMusicSync
                    )
                    
                    // Footer spacing
                    Spacer()
                        .frame(height: DesignTokens.Spacing.xxl)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
        .onAppear {
            logger.info("ContentView appeared")
        }
    }
    
    private var backgroundView: some View {
        themeManager.currentTheme.primaryGradient
            .ignoresSafeArea()
    }
    
    private func toggleMusicSync(_ isActive: Bool) {
        logger.info("Toggling music sync: \(isActive)")
        isMusicSyncActive = isActive

        if isActive {
            audioAnalyzer.startAudioCapture { red, green, blue in
                bleManager.sendRGB(red: red, green: green, blue: blue)
            }
        } else {
            audioAnalyzer.stopCurrentCapture()
        }
    }
}

// MARK: - Music Sync Control View

struct MusicSyncControlView: View {
    @Binding var isMusicSyncActive: Bool
    let onToggle: (Bool) -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var bleManager: BLEManager
    
    private let logger = Logger(subsystem: "com.musiclightsync.main", category: "MusicSyncControlView")
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Sync Control Button
            syncControlButton
            
            // Connection Status Warning
            if !bleManager.isConnected {
                connectionWarning
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(themeManager.currentTheme.cardBackground)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .shadow(
            color: DesignTokens.Shadow.md.color,
            radius: DesignTokens.Shadow.md.radius,
            x: DesignTokens.Shadow.md.x,
            y: DesignTokens.Shadow.md.y
        )
    }
    
    private var syncControlButton: some View {
        Button(action: {
            logger.info("Music sync button tapped")
            let newState = !isMusicSyncActive
            onToggle(newState)
        }) {
            HStack {
                Image(systemName: isMusicSyncActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: DesignTokens.FontSize.title2, weight: .bold))
                
                Text(isMusicSyncActive ? "Stop Music Sync" : "Start Music Sync")
                    .font(.system(size: DesignTokens.FontSize.body, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.lg)
            .background(buttonBackground)
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(
                color: buttonShadowColor,
                radius: 15,
                x: 0,
                y: 8
            )
        }
        .disabled(!bleManager.isConnected)
        .scaleEffect(isMusicSyncActive ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isMusicSyncActive)
    }
    
    private var buttonBackground: LinearGradient {
        isMusicSyncActive ? 
        LinearGradient(colors: [themeManager.currentTheme.errorColor], startPoint: .leading, endPoint: .trailing) :
        themeManager.currentTheme.secondaryGradient
    }
    
    private var buttonShadowColor: Color {
        isMusicSyncActive ? 
        themeManager.currentTheme.errorColor.opacity(0.4) :
        themeManager.currentTheme.accentColor.opacity(0.4)
    }
    
    private var connectionWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(themeManager.currentTheme.errorColor)
            
            Text("Connect to a device to enable music sync")
                .font(.system(size: DesignTokens.FontSize.caption, weight: .medium))
                .foregroundColor(themeManager.currentTheme.textSecondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(themeManager.currentTheme.errorColor.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
}

// MARK: - Pattern Type Enum (Keep for compatibility)

enum PatternType: String, Codable, CaseIterable {
    case staticColor = "static"
    case fade = "fade"
    case flash = "flash"
    case colorWheel = "colorWheel"
}

// MARK: - LED Preset Model (Keep for compatibility)

struct LEDPreset: Codable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let brightness: Double
    let pattern: PatternType
    let speed: Double
}

