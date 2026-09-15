//
//  MusicSensitivityView.swift
//  MusicLightSync
//
//  Created by Rahul Srivastava on 06/04/25.
//

import SwiftUI
import os.log

// MARK: - Music Sensitivity Controls Component

class MusicSensitivityViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.musiclightsync.sensitivity", category: "MusicSensitivityViewModel")
    
    @Published var musicBrightness: Double = 0.8
    @Published var colorSensitivity: Double = 0.6
    @Published var beatResponse: Double = 0.5
    @Published var frequencyResponse: Double = 0.7
    @Published var isAutoAdjustEnabled: Bool = false
    
    init() {
        logger.info("MusicSensitivityViewModel initialized with default values")
        loadSettings()
    }
    
    private func loadSettings() {
        logger.info("Loading music sensitivity settings from UserDefaults")
        musicBrightness = UserDefaults.standard.double(forKey: "musicBrightness") != 0 ? 
            UserDefaults.standard.double(forKey: "musicBrightness") : 0.8
        colorSensitivity = UserDefaults.standard.double(forKey: "colorSensitivity") != 0 ? 
            UserDefaults.standard.double(forKey: "colorSensitivity") : 0.6
        beatResponse = UserDefaults.standard.double(forKey: "beatResponse") != 0 ? 
            UserDefaults.standard.double(forKey: "beatResponse") : 0.5
        frequencyResponse = UserDefaults.standard.double(forKey: "frequencyResponse") != 0 ? 
            UserDefaults.standard.double(forKey: "frequencyResponse") : 0.7
        isAutoAdjustEnabled = UserDefaults.standard.bool(forKey: "isAutoAdjustEnabled")
    }
    
    func saveSettings() {
        logger.info("Saving music sensitivity settings to UserDefaults")
        UserDefaults.standard.set(musicBrightness, forKey: "musicBrightness")
        UserDefaults.standard.set(colorSensitivity, forKey: "colorSensitivity")
        UserDefaults.standard.set(beatResponse, forKey: "beatResponse")
        UserDefaults.standard.set(frequencyResponse, forKey: "frequencyResponse")
        UserDefaults.standard.set(isAutoAdjustEnabled, forKey: "isAutoAdjustEnabled")
        logger.info("Settings saved successfully")
    }
    
    func resetToDefaults() {
        logger.info("Resetting music sensitivity to default values")
        musicBrightness = 0.8
        colorSensitivity = 0.6
        beatResponse = 0.5
        frequencyResponse = 0.7
        isAutoAdjustEnabled = false
        saveSettings()
    }
}

struct MusicSensitivityView: View {
    @StateObject private var viewModel = MusicSensitivityViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var audioAnalyzer: AudioAnalyzer
    
    private let logger = Logger(subsystem: "com.musiclightsync.sensitivity", category: "MusicSensitivityView")
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: DesignTokens.FontSize.title3, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .shadow(color: themeManager.currentTheme.accentColor.opacity(0.5), radius: 5)
                
                Text("Music Sensitivity")
                    .font(.system(size: DesignTokens.FontSize.title3, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.textPrimary)
                
                Spacer()
                
                // Auto-adjust toggle
                Toggle("Auto", isOn: $viewModel.isAutoAdjustEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.accentColor))
                    .onChange(of: viewModel.isAutoAdjustEnabled) { value in
                        logger.info("Auto-adjust toggled: \(value)")
                        viewModel.saveSettings()
                    }
            }
            
            // Sensitivity Controls
            VStack(spacing: DesignTokens.Spacing.md) {
                // Music Brightness
                SensitivitySlider(
                    title: "Music Brightness",
                    icon: "sun.max.fill",
                    value: $viewModel.musicBrightness,
                    color: themeManager.currentTheme.accentColor,
                    onValueChanged: { value in
                        logger.info("Music brightness changed to \(value)")
                        audioAnalyzer.updateMusicBrightness(value)
                        viewModel.saveSettings()
                    }
                )
                
                // Color Sensitivity
                SensitivitySlider(
                    title: "Color Sensitivity",
                    icon: "paintbrush.fill",
                    value: $viewModel.colorSensitivity,
                    color: Color(hex: "FF6B6B"),
                    onValueChanged: { value in
                        logger.info("Color sensitivity changed to \(value)")
                        audioAnalyzer.updateColorSensitivity(value)
                        viewModel.saveSettings()
                    }
                )
                
                // Beat Response
                SensitivitySlider(
                    title: "Beat Response",
                    icon: "heart.fill",
                    value: $viewModel.beatResponse,
                    color: Color(hex: "4ECDC4"),
                    onValueChanged: { value in
                        logger.info("Beat response changed to \(value)")
                        audioAnalyzer.updateBeatResponse(value)
                        viewModel.saveSettings()
                    }
                )
                
                // Frequency Response
                SensitivitySlider(
                    title: "Frequency Response",
                    icon: "waveform",
                    value: $viewModel.frequencyResponse,
                    color: Color(hex: "A8E6CF"),
                    onValueChanged: { value in
                        logger.info("Frequency response changed to \(value)")
                        audioAnalyzer.updateFrequencyResponse(value)
                        viewModel.saveSettings()
                    }
                )
            }
            
            // Reset Button
            Button(action: {
                logger.info("Reset button tapped")
                viewModel.resetToDefaults()
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                        .fontWeight(.medium)
                }
                .foregroundColor(themeManager.currentTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(themeManager.currentTheme.surfaceColor)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 1)
                )
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
        .onAppear {
            logger.info("MusicSensitivityView appeared")
        }
    }
}

// MARK: - Custom Sensitivity Slider

struct SensitivitySlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let color: Color
    let onValueChanged: (Double) -> Void
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: DesignTokens.FontSize.body, weight: .medium))
                
                Text(title)
                    .font(.system(size: DesignTokens.FontSize.body, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                    .foregroundColor(color)
                    .frame(minWidth: 50, alignment: .trailing)
            }
            
            Slider(value: $value, in: 0...1, step: 0.01)
                .accentColor(color)
                .onChange(of: value) { newValue in
                    onValueChanged(newValue)
                }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(Color.black.opacity(0.2))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
} 