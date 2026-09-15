//
//  HeaderView.swift
//  MusicLightSync
//
//  Created by Rahul Srivastava on 06/04/25.
//

import SwiftUI
import os.log

// MARK: - Header View Component

class HeaderViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.musiclightsync.header", category: "HeaderViewModel")
    
    @Published var isAnimating: Bool = false
    @Published var shouldShowStatus: Bool = true
    
    init() {
        logger.info("HeaderViewModel initialized")
        startAnimation()
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
    }
    
    func toggleStatusVisibility() {
        logger.info("Toggling status visibility")
        shouldShowStatus.toggle()
    }
}

struct HeaderView: View {
    @StateObject private var viewModel = HeaderViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var bleManager: BLEManager
    @EnvironmentObject private var audioAnalyzer: AudioAnalyzer
    
    private let logger = Logger(subsystem: "com.musiclightsync.header", category: "HeaderView")
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Main Title Section
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    // Animated Music Icon
                    Image(systemName: "music.note")
                        .font(.system(size: DesignTokens.FontSize.largeTitle, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                        .scaleEffect(viewModel.isAnimating ? 1.2 : 1.0)
                        .rotationEffect(.degrees(viewModel.isAnimating ? 10 : -10))
                        .shadow(
                            color: DesignTokens.Shadow.glow.color,
                            radius: DesignTokens.Shadow.glow.radius,
                            x: DesignTokens.Shadow.glow.x,
                            y: DesignTokens.Shadow.glow.y
                        )
                    
                    // App Title
                    Text("Music Sync")
                        .font(.system(size: DesignTokens.FontSize.largeTitle, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.textPrimary)
                        .background(
                            themeManager.currentTheme.secondaryGradient
                                .mask(
                                    Text("Music Sync")
                                        .font(.system(size: DesignTokens.FontSize.largeTitle, weight: .bold, design: .rounded))
                                )
                        )
                    
                    Spacer()
                }
                
                // Subtitle
                HStack {
                    Text("LED Controller")
                        .font(.system(size: DesignTokens.FontSize.title2, weight: .medium, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                    
                    Spacer()
                    
                    // Status Indicators
                    if viewModel.shouldShowStatus {
                        StatusIndicatorView()
                    }
                }
            }
            
            // Animated Wave Bar
            AnimatedWaveBar()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.lg)
        .onAppear {
            logger.info("HeaderView appeared")
        }
    }
}

// MARK: - Status Indicator View

struct StatusIndicatorView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var bleManager: BLEManager
    @EnvironmentObject private var audioAnalyzer: AudioAnalyzer
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Audio Status
            StatusDot(
                isActive: audioAnalyzer.isAnalyzing,
                activeColor: themeManager.currentTheme.successColor,
                inactiveColor: themeManager.currentTheme.textSecondary,
                icon: "waveform"
            )
            
            // Bluetooth Status
            StatusDot(
                isActive: bleManager.isConnected,
                activeColor: Color(hex: "4ECDC4"),
                inactiveColor: themeManager.currentTheme.textSecondary,
                icon: "bluetooth"
            )
            
            // CarPlay Status
            if audioAnalyzer.isCarPlayConnected {
                StatusDot(
                    isActive: true,
                    activeColor: Color(hex: "FFD93D"),
                    inactiveColor: themeManager.currentTheme.textSecondary,
                    icon: "car.fill"
                )
            }
        }
    }
}

// MARK: - Status Dot Component

struct StatusDot: View {
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.FontSize.caption, weight: .medium))
                .foregroundColor(isActive ? activeColor : inactiveColor)
            
            Circle()
                .fill(isActive ? activeColor : inactiveColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.3) : Color.clear)
                        .scaleEffect(isActive ? 2.0 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isActive)
                )
        }
    }
}

// MARK: - Animated Wave Bar

struct AnimatedWaveBar: View {
    @State private var waveOffset: CGFloat = 0
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var audioAnalyzer: AudioAnalyzer
    
    var body: some View {
        ZStack {
            // Background wave
            WaveShape(offset: waveOffset, percent: 0.3)
                .fill(themeManager.currentTheme.accentColor.opacity(0.1))
                .frame(height: 30)
            
            // Active wave (responds to audio)
            WaveShape(offset: waveOffset * 1.5, percent: audioAnalyzer.isAnalyzing ? 0.6 : 0.2)
                .fill(themeManager.currentTheme.accentColor.opacity(0.3))
                .frame(height: 30)
            
            // Foreground wave
            WaveShape(offset: waveOffset * 2, percent: 0.1)
                .fill(themeManager.currentTheme.accentColor.opacity(0.6))
                .frame(height: 30)
        }
        .cornerRadius(DesignTokens.CornerRadius.md)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                waveOffset = 2 * .pi
            }
        }
    }
}

// MARK: - Wave Shape

struct WaveShape: Shape {
    var offset: CGFloat
    let percent: CGFloat
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let midHeight = height * percent
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * 4 * .pi + offset)
            let y = midHeight + sine * (height * 0.3)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
} 