//
//  LEDControlsView.swift
//  MusicLightSync
//
//  Created by Rahul Srivastava on 06/04/25.
//

import SwiftUI
import os.log

// MARK: - LED Controls View Component

class LEDControlsViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.musiclightsync.ledcontrols", category: "LEDControlsViewModel")
    
    @Published var selectedColor: Color = .red
    @Published var brightness: Double = 0.8
    @Published var animationSpeed: Double = 1.0
    @Published var currentPattern: PatternType = .staticColor
    @Published var isAnimating: Bool = false
    
    init() {
        logger.info("LEDControlsViewModel initialized")
        loadSettings()
    }
    
    private func loadSettings() {
        logger.info("Loading LED control settings")
        brightness = UserDefaults.standard.double(forKey: "ledBrightness") != 0 ? 
            UserDefaults.standard.double(forKey: "ledBrightness") : 0.8
        animationSpeed = UserDefaults.standard.double(forKey: "ledAnimationSpeed") != 0 ? 
            UserDefaults.standard.double(forKey: "ledAnimationSpeed") : 1.0
        
        if let patternRaw = UserDefaults.standard.string(forKey: "ledPattern"),
           let pattern = PatternType(rawValue: patternRaw) {
            currentPattern = pattern
        }
    }
    
    func saveSettings() {
        logger.info("Saving LED control settings")
        UserDefaults.standard.set(brightness, forKey: "ledBrightness")
        UserDefaults.standard.set(animationSpeed, forKey: "ledAnimationSpeed")
        UserDefaults.standard.set(currentPattern.rawValue, forKey: "ledPattern")
    }
    
    func updatePattern(_ pattern: PatternType) {
        logger.info("Pattern updated to: \(pattern.rawValue)")
        currentPattern = pattern
        saveSettings()
    }
    
    func updateBrightness(_ value: Double) {
        logger.info("Brightness updated to: \(value)")
        brightness = value
        saveSettings()
    }
    
    func updateAnimationSpeed(_ value: Double) {
        logger.info("Animation speed updated to: \(value)")
        animationSpeed = value
        saveSettings()
    }
}

struct LEDControlsView: View {
    @StateObject private var viewModel = LEDControlsViewModel()
    @EnvironmentObject private var bleManager: BLEManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    private let logger = Logger(subsystem: "com.musiclightsync.ledcontrols", category: "LEDControlsView")
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: DesignTokens.FontSize.title3, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .shadow(
                        color: DesignTokens.Shadow.glow.color,
                        radius: DesignTokens.Shadow.glow.radius,
                        x: DesignTokens.Shadow.glow.x,
                        y: DesignTokens.Shadow.glow.y
                    )
                
                Text("LED Controls")
                    .font(.system(size: DesignTokens.FontSize.title3, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.textPrimary)
                
                Spacer()
            }
            
            // Color Preview Circle
            ColorPreviewCircle(
                color: viewModel.selectedColor,
                brightness: viewModel.brightness,
                isAnimating: viewModel.isAnimating
            )
            
            // Color Picker
            ColorSelectionView(
                selectedColor: $viewModel.selectedColor,
                onColorChanged: { color in
                    logger.info("Color changed")
                    sendCurrentColor()
                }
            )
            
            // Control Sliders
            VStack(spacing: DesignTokens.Spacing.md) {
                // Brightness Control
                ControlSlider(
                    title: "Brightness",
                    icon: "sun.max.fill",
                    value: $viewModel.brightness,
                    range: 0...1,
                    color: themeManager.currentTheme.accentColor,
                    onValueChanged: { value in
                        viewModel.updateBrightness(value)
                        sendCurrentColor()
                    }
                )
                
                // Animation Speed Control
                ControlSlider(
                    title: "Animation Speed",
                    icon: "speedometer",
                    value: $viewModel.animationSpeed,
                    range: 0.1...3.0,
                    color: Color(hex: "FF6B6B"),
                    onValueChanged: { value in
                        viewModel.updateAnimationSpeed(value)
                        if viewModel.currentPattern != .staticColor {
                            sendPatternCommand()
                        }
                    }
                )
            }
            
            // Pattern Selection
            PatternSelectionView(
                currentPattern: $viewModel.currentPattern,
                onPatternChanged: { pattern in
                    viewModel.updatePattern(pattern)
                    sendPatternCommand()
                }
            )
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
            logger.info("LEDControlsView appeared")
        }
    }
    
    private func sendCurrentColor() {
        let uiColor = UIColor(viewModel.selectedColor)
        guard let components = uiColor.cgColor.components else { return }
        let red = UInt8(components[0] * 255 * viewModel.brightness)
        let green = UInt8(components[1] * 255 * viewModel.brightness)
        let blue = UInt8(components[2] * 255 * viewModel.brightness)
        
        logger.info("Sending RGB: R:\(red), G:\(green), B:\(blue)")
        bleManager.sendRGB(red: red, green: green, blue: blue)
    }
    
    private func sendPatternCommand() {
        logger.info("Sending pattern command: \(viewModel.currentPattern.rawValue)")
        bleManager.sendPatternCommand(
            pattern: viewModel.currentPattern,
            brightness: viewModel.brightness,
            speed: viewModel.animationSpeed
        )
    }
}

// MARK: - Color Preview Circle

struct ColorPreviewCircle: View {
    let color: Color
    let brightness: Double
    let isAnimating: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Circle()
            .fill(color.opacity(brightness))
            .frame(width: 120, height: 120)
            .overlay(
                Circle()
                    .stroke(themeManager.currentTheme.textPrimary.opacity(0.3), lineWidth: 2)
            )
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 4)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isAnimating)
            )
            .shadow(color: color.opacity(0.6), radius: 20)
    }
}

// MARK: - Color Selection View

struct ColorSelectionView: View {
    @Binding var selectedColor: Color
    let onColorChanged: (Color) -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    private let presetColors: [Color] = [
        .red, .green, .blue, .purple, .orange, .pink,
        Color(hex: "FF6B6B"), Color(hex: "4ECDC4"), Color(hex: "45B7D1"),
        Color(hex: "96CEB4"), Color(hex: "FFEAA7"), Color(hex: "DDA0DD")
    ]
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Custom Color Picker
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Custom Color")
                    .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.textSecondary)
                
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .frame(height: 40)
                    .onChange(of: selectedColor) { _ in
                        onColorChanged(selectedColor)
                    }
            }
            
            // Preset Colors
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Preset Colors")
                    .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.textSecondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: DesignTokens.Spacing.sm) {
                    ForEach(presetColors.indices, id: \.self) { index in
                        PresetColorButton(
                            color: presetColors[index],
                            isSelected: selectedColor == presetColors[index],
                            onTap: {
                                selectedColor = presetColors[index]
                                onColorChanged(selectedColor)
                            }
                        )
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(themeManager.currentTheme.surfaceColor.opacity(0.5))
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
}

// MARK: - Preset Color Button

struct PresetColorButton: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: color.opacity(0.6), radius: isSelected ? 8 : 4)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Control Slider

struct ControlSlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
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
                
                Text(formatValue(value))
                    .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                    .foregroundColor(color)
                    .frame(minWidth: 50, alignment: .trailing)
            }
            
            Slider(value: $value, in: range, step: 0.01)
                .accentColor(color)
                .onChange(of: value) { newValue in
                    onValueChanged(newValue)
                }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(Color.black.opacity(0.2))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }
    
    private func formatValue(_ value: Double) -> String {
        if title == "Brightness" {
            return "\(Int(value * 100))%"
        } else {
            return String(format: "%.1fx", value)
        }
    }
}

// MARK: - Pattern Selection View

struct PatternSelectionView: View {
    @Binding var currentPattern: PatternType
    let onPatternChanged: (PatternType) -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Light Patterns")
                .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.textSecondary)
            
            HStack(spacing: DesignTokens.Spacing.sm) {
                PatternButton(
                    pattern: .staticColor,
                    icon: "circle.fill",
                    label: "Static",
                    isSelected: currentPattern == .staticColor,
                    onTap: { onPatternChanged(.staticColor) }
                )
                
                PatternButton(
                    pattern: .fade,
                    icon: "waveform.path.ecg",
                    label: "Fade",
                    isSelected: currentPattern == .fade,
                    onTap: { onPatternChanged(.fade) }
                )
                
                PatternButton(
                    pattern: .flash,
                    icon: "bolt.fill",
                    label: "Flash",
                    isSelected: currentPattern == .flash,
                    onTap: { onPatternChanged(.flash) }
                )
                
                PatternButton(
                    pattern: .colorWheel,
                    icon: "paintpalette.fill",
                    label: "Wheel",
                    isSelected: currentPattern == .colorWheel,
                    onTap: { onPatternChanged(.colorWheel) }
                )
            }
        }
    }
}

// MARK: - Pattern Button

struct PatternButton: View {
    let pattern: PatternType
    let icon: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.FontSize.title3, weight: .semibold))
                    .foregroundColor(isSelected ? themeManager.currentTheme.accentColor : themeManager.currentTheme.textSecondary)
                
                Text(label)
                    .font(.system(size: DesignTokens.FontSize.caption, weight: .medium))
                    .foregroundColor(isSelected ? themeManager.currentTheme.accentColor : themeManager.currentTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isSelected ? themeManager.currentTheme.accentColor.opacity(0.2) : themeManager.currentTheme.surfaceColor)
            .cornerRadius(DesignTokens.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(isSelected ? themeManager.currentTheme.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 