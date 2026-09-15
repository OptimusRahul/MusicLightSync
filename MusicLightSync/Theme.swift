//
//  Theme.swift
//  MusicLightSync
//
//  Created by Rahul Srivastava on 06/04/25.
//

import SwiftUI
import os.log

// MARK: - Modern Theme System for Music Light Sync

class ThemeManager: ObservableObject {
    private let logger = Logger(subsystem: "com.musiclightsync.theme", category: "ThemeManager")
    
    @Published var currentTheme: AppTheme = CyberpunkTheme()
    
    init() {
        logger.info("ThemeManager initialized with \(self.currentTheme.name) theme")
    }
    
    func switchTheme(_ newTheme: AppTheme) {
        logger.info("Switching theme from \(self.currentTheme.name) to \(newTheme.name)")
        currentTheme = newTheme
    }
}

// MARK: - Theme Protocol

protocol AppTheme {
    var name: String { get }
    var primaryGradient: LinearGradient { get }
    var secondaryGradient: LinearGradient { get }
    var accentColor: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var cardBackground: Color { get }
    var shadowColor: Color { get }
    var successColor: Color { get }
    var errorColor: Color { get }
    var surfaceColor: Color { get }
}

// MARK: - Cyberpunk Theme

struct CyberpunkTheme: AppTheme {
    let name = "Cyberpunk"
    
    let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "0A0A0A"),
            Color(hex: "1A1A2E"),
            Color(hex: "16213E")
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    let secondaryGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "E94560"),
            Color(hex: "F16283")
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    let accentColor = Color(hex: "00F5FF")
    let textPrimary = Color.white
    let textSecondary = Color(hex: "B0B0B0")
    let cardBackground = Color(hex: "0F3460").opacity(0.8)
    let shadowColor = Color.black.opacity(0.3)
    let successColor = Color(hex: "00FF88")
    let errorColor = Color(hex: "FF3366")
    let surfaceColor = Color(hex: "1E1E2E")
}

// MARK: - Theme Factory

struct ThemeFactory {
    static let cyberpunk: AppTheme = CyberpunkTheme()
    
    static func getTheme(named name: String) -> AppTheme {
        switch name.lowercased() {
        case "cyberpunk":
            return cyberpunk
        default:
            return cyberpunk
        }
    }
}

// MARK: - Design Tokens

struct DesignTokens {
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let circle: CGFloat = 50
    }
    
    struct FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let title3: CGFloat = 20
        static let title2: CGFloat = 24
        static let title1: CGFloat = 28
        static let largeTitle: CGFloat = 34
    }
    
    struct Shadow {
        static let sm = (color: Color.black.opacity(0.1), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let md = (color: Color.black.opacity(0.2), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let lg = (color: Color.black.opacity(0.3), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
        static let glow = (color: Color(hex: "00F5FF").opacity(0.3), radius: CGFloat(10), x: CGFloat(0), y: CGFloat(0))
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
} 