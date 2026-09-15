//
//  MusicLightSyncApp.swift
//  MusicLightSync
//
//  Created by Rahul Srivastava on 06/04/25.
//

import SwiftUI
import AVFoundation
import CoreBluetooth
import MediaPlayer
import os.log

// MARK: - Complete Advanced LED Sync App with Modern Architecture

@main
struct MusicLightSyncApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var bleManager = BLEManager()
    @StateObject private var audioAnalyzer = AudioAnalyzer()
    
    private let logger = Logger(subsystem: "com.musiclightsync.app", category: "MusicLightSyncApp")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(bleManager)
                .environmentObject(audioAnalyzer)
                .onAppear {
                    logger.info("MusicLightSyncApp started")
                    setupAudioSession()
                }
        }
    }
    
    private func setupAudioSession() {
        logger.info("Setting up audio session")
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetoothA2DP, .mixWithOthers]
            )

            // Force the built-in mic so we never grab the car's Bluetooth mic input,
            // which would otherwise force iOS to drop the car's A2DP link (hi-fi stereo)
            // down to HFP (phone-call quality, mono, no bass) for the whole system.
            if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try audioSession.setPreferredInput(builtInMic)
            }

            try audioSession.setActive(true)
            logger.info("Audio session setup successful")
        } catch {
            logger.error("Failed to set up audio session: \(error)")
        }
    }
}
