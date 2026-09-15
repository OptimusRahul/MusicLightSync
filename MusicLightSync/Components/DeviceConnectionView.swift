//
//  DeviceConnectionView.swift
//  MusicLightSync
//
//  Created by Rahul Srivastava on 06/04/25.
//

import SwiftUI
import os.log

// MARK: - Device Connection View Component

class DeviceConnectionViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.musiclightsync.connection", category: "DeviceConnectionViewModel")
    
    @Published var isScanning: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var scanAnimation: Bool = false
    
    init() {
        logger.info("DeviceConnectionViewModel initialized")
    }
    
    func startScanning() {
        logger.info("Starting device scanning")
        isScanning = true
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            scanAnimation = true
        }
    }
    
    func stopScanning() {
        logger.info("Stopping device scanning")
        isScanning = false
        scanAnimation = false
    }
    
    func updateConnectionStatus(_ status: ConnectionStatus) {
        logger.info("Connection status updated to: \(status.rawValue)")
        connectionStatus = status
    }
    
    enum ConnectionStatus: String, CaseIterable {
        case disconnected = "Disconnected"
        case connecting = "Connecting"
        case connected = "Connected"
        case error = "Error"
        
        var color: Color {
            switch self {
            case .disconnected: return Color(hex: "FF6B6B")
            case .connecting: return Color(hex: "FFD93D")
            case .connected: return Color(hex: "6BCF7F")
            case .error: return Color(hex: "FF4757")
            }
        }
        
        var icon: String {
            switch self {
            case .disconnected: return "wifi.slash"
            case .connecting: return "wifi.exclamationmark"
            case .connected: return "wifi"
            case .error: return "wifi.slash"
            }
        }
    }
}

struct DeviceConnectionView: View {
    @StateObject private var viewModel = DeviceConnectionViewModel()
    @EnvironmentObject private var bleManager: BLEManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    private let logger = Logger(subsystem: "com.musiclightsync.connection", category: "DeviceConnectionView")
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Header with Connection Status
            HStack {
                // Connection Status Indicator
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: viewModel.connectionStatus.icon)
                        .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                        .foregroundColor(viewModel.connectionStatus.color)
                        .scaleEffect(viewModel.scanAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.scanAnimation)
                    
                    Text(viewModel.connectionStatus.rawValue)
                        .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.textPrimary)
                }
                
                Spacer()
                
                // Connection Indicator Light
                Circle()
                    .fill(viewModel.connectionStatus.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(viewModel.connectionStatus.color.opacity(0.3))
                            .scaleEffect(viewModel.scanAnimation ? 2.0 : 1.5)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.scanAnimation)
                    )
            }
            
            // Connection Controls
            if !bleManager.isConnected {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Scan Button
                    Button(action: {
                        logger.info("Scan button tapped")
                        if viewModel.isScanning {
                            viewModel.stopScanning()
                            bleManager.centralManager.stopScan()
                        } else {
                            viewModel.startScanning()
                            bleManager.scanForDevices()
                        }
                    }) {
                        HStack {
                            Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "magnifyingglass")
                                .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                                .rotationEffect(.degrees(viewModel.scanAnimation ? 360 : 0))
                                .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: viewModel.scanAnimation)
                            
                            Text(viewModel.isScanning ? "Stop Scanning" : "Scan for Devices")
                                .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                        }
                        .foregroundColor(themeManager.currentTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background(themeManager.currentTheme.secondaryGradient)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                        .shadow(
                            color: themeManager.currentTheme.accentColor.opacity(0.3),
                            radius: DesignTokens.Shadow.md.radius,
                            x: DesignTokens.Shadow.md.x,
                            y: DesignTokens.Shadow.md.y
                        )
                    }
                    .scaleEffect(viewModel.scanAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.scanAnimation)
                    
                    // Discovered Devices List
                    if !bleManager.discoveredPeripherals.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Discovered Devices")
                                .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                                .foregroundColor(themeManager.currentTheme.textSecondary)
                            
                            ScrollView {
                                LazyVStack(spacing: DesignTokens.Spacing.sm) {
                                    ForEach(Array(bleManager.discoveredPeripherals.keys), id: \.self) { deviceName in
                                        DeviceListItem(
                                            deviceName: deviceName,
                                            onTap: {
                                                logger.info("Device selected: \(deviceName)")
                                                viewModel.updateConnectionStatus(.connecting)
                                                bleManager.connectToDevice(named: deviceName)
                                            }
                                        )
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                        }
                        .transition(.slide.combined(with: .opacity))
                    }
                }
            } else {
                // Connected Device Info
                VStack(spacing: DesignTokens.Spacing.md) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: DesignTokens.FontSize.title2, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.successColor)
                        
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Connected to")
                                .font(.system(size: DesignTokens.FontSize.caption, weight: .medium))
                                .foregroundColor(themeManager.currentTheme.textSecondary)
                            
                            Text(bleManager.connectedDeviceName)
                                .font(.system(size: DesignTokens.FontSize.body, weight: .bold))
                                .foregroundColor(themeManager.currentTheme.textPrimary)
                        }
                        
                        Spacer()
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(themeManager.currentTheme.successColor.opacity(0.1))
                    .cornerRadius(DesignTokens.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .stroke(themeManager.currentTheme.successColor.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Disconnect Button
                    Button(action: {
                        logger.info("Disconnect button tapped")
                        viewModel.updateConnectionStatus(.disconnected)
                        bleManager.disconnectDevice()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                            
                            Text("Disconnect")
                                .font(.system(size: DesignTokens.FontSize.body, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(themeManager.currentTheme.errorColor)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                        .shadow(
                            color: themeManager.currentTheme.errorColor.opacity(0.3),
                            radius: DesignTokens.Shadow.sm.radius,
                            x: DesignTokens.Shadow.sm.x,
                            y: DesignTokens.Shadow.sm.y
                        )
                    }
                }
                .transition(.slide.combined(with: .opacity))
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
        .onReceive(bleManager.$isConnected) { isConnected in
            if isConnected {
                viewModel.updateConnectionStatus(.connected)
                viewModel.stopScanning()
            } else if !bleManager.isReconnecting {
                viewModel.updateConnectionStatus(.disconnected)
            }
        }
        .onReceive(bleManager.$isReconnecting) { isReconnecting in
            if isReconnecting {
                viewModel.updateConnectionStatus(.connecting)
            }
        }
        .onAppear {
            logger.info("DeviceConnectionView appeared")
        }
    }
}

// MARK: - Device List Item Component

struct DeviceListItem: View {
    let deviceName: String
    let onTap: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: DesignTokens.FontSize.body, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                
                Text(deviceName)
                    .font(.system(size: DesignTokens.FontSize.body, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: DesignTokens.FontSize.caption, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(themeManager.currentTheme.surfaceColor)
            .cornerRadius(DesignTokens.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(themeManager.currentTheme.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 