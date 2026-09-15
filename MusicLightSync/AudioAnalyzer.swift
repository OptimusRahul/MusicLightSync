import SwiftUI
import AVFoundation
import AudioKit
import Combine
import UIKit
import os.log

class AudioAnalyzer: ObservableObject {
    private let logger = Logger(subsystem: "com.musiclightsync.audio", category: "AudioAnalyzer")
    
    private var mic: AudioEngine.InputNode?
    private var tracker: AmplitudeTap?
    private var fftTap: FFTTap?
    private var engine: AudioEngine?

    @Published var isAnalyzing: Bool = false
    @Published var visualizationMode: AudioVisualizationMode = .amplitude
    @Published var sensitivity: Float = 1.0
    @Published var isCarPlayConnected: Bool = false
    
    // New sensitivity controls
    @Published var musicBrightness: Double = 0.8
    @Published var colorSensitivity: Double = 0.6
    @Published var beatResponse: Double = 0.5
    @Published var frequencyResponse: Double = 0.7

    private var beatDetector = BeatDetector()
    private var lastBeatTime: TimeInterval = 0
    private var beatAnimationTrigger = PassthroughSubject<Void, Never>()

    var onBeatDetected: (() -> Void)?

    private var activeColorCallback: ((UInt8, UInt8, UInt8) -> Void)?

    init() {
        logger.info("AudioAnalyzer initialized")
        NotificationCenter.default.addObserver(self, selector: #selector(checkCarPlayConnection), name: UIScene.didActivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
        checkCarPlayConnection()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func checkCarPlayConnection() {
        logger.info("Checking CarPlay connection status")
        let routes = AVAudioSession.sharedInstance().currentRoute.outputs
        self.isCarPlayConnected = routes.contains { output in
            output.portType == .carAudio || output.portName.contains("Car")
        }
        logger.info("CarPlay connected: \(self.isCarPlayConnected)")
    }

    enum AudioVisualizationMode {
        case amplitude, frequency, colorWheel
    }

    // MARK: - New Sensitivity Control Methods
    
    func updateMusicBrightness(_ value: Double) {
        logger.info("Updating music brightness to \(value)")
        musicBrightness = value
        beatDetector.updateBrightnessSensitivity(Float(value))
    }
    
    func updateColorSensitivity(_ value: Double) {
        logger.info("Updating color sensitivity to \(value)")
        colorSensitivity = value
        sensitivity = Float(value)
    }
    
    func updateBeatResponse(_ value: Double) {
        logger.info("Updating beat response to \(value)")
        beatResponse = value
        beatDetector.updateBeatSensitivity(Float(value))
    }
    
    func updateFrequencyResponse(_ value: Double) {
        logger.info("Updating frequency response to \(value)")
        frequencyResponse = value
    }

    func startAudioCapture(onColorValues: @escaping (UInt8, UInt8, UInt8) -> Void) {
        teardownEngine()
        activeColorCallback = onColorValues
        engine = AudioEngine()
        guard let engine = engine else {
            logger.error("Failed to create AudioEngine")
            return
        }

        setupMicrophoneAnalysis(onColorValues: onColorValues)

        do {
            try engine.start()
            isAnalyzing = true
            logger.info("Audio capture started successfully")
        } catch {
            logger.error("Error starting AudioKit engine: \(error)")
            isAnalyzing = false
        }
    }

    func stopCurrentCapture() {
        logger.info("Stopping current audio capture")
        teardownEngine()
        activeColorCallback = nil
    }

    private func teardownEngine() {
        tracker?.stop()
        fftTap?.stop()
        engine?.stop()
        mic = nil
        tracker = nil
        fftTap = nil
        engine = nil
        isAnalyzing = false
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            guard isAnalyzing else { return }
            logger.info("Audio session interrupted - pausing capture")
            teardownEngine()
        case .ended:
            guard let callback = activeColorCallback else { return }
            var shouldResume = false
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            }
            guard shouldResume else { return }
            logger.info("Resuming audio capture after interruption")
            try? AVAudioSession.sharedInstance().setActive(true)
            startAudioCapture(onColorValues: callback)
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        logger.info("Audio route changed, reason: \(reason.rawValue)")
        checkCarPlayConnection()

        switch reason {
        case .oldDeviceUnavailable, .categoryChange, .routeConfigurationChange:
            guard isAnalyzing, let callback = activeColorCallback else { return }
            logger.info("Restarting audio capture after route change")
            startAudioCapture(onColorValues: callback)
        default:
            break
        }
    }

    private func setupMicrophoneAnalysis(onColorValues: @escaping (UInt8, UInt8, UInt8) -> Void) {
        logger.info("Setting up microphone analysis")
        mic = engine?.input
        guard let mic = mic else { 
            logger.error("Failed to get microphone input")
            return 
        }

        switch visualizationMode {
        case .amplitude:
            tracker = AmplitudeTap(mic) { amplitude in
                let adjustedAmp = min(max(amplitude * 300 * self.sensitivity * Float(self.musicBrightness), 0), 255)
                onColorValues(UInt8(adjustedAmp), UInt8(adjustedAmp * 0.2), UInt8(adjustedAmp * 0.4))
                
                // Beat detection with brightness adjustment
                if self.beatDetector.detectBeat(amplitude: amplitude, sensitivity: Float(self.beatResponse)) {
                    self.onBeatDetected?()
                }
            }
            tracker?.start()
            logger.info("Amplitude tracking started")
        case .frequency, .colorWheel:
            fftTap = FFTTap(mic) { fftData in
                self.analyzeFFT(fftData, mode: self.visualizationMode, onColorValues: onColorValues)
            }
            fftTap?.start()
            logger.info("FFT analysis started")
        }
    }

    private func analyzeFFT(_ fftData: [Float], mode: AudioVisualizationMode, onColorValues: @escaping (UInt8, UInt8, UInt8) -> Void) {
        let frequencyMultiplier = Float(frequencyResponse)
        let brightnessMultiplier = Float(musicBrightness)
        let colorMultiplier = Float(colorSensitivity)
        
        switch mode {
        case .frequency:
            let bassEnergy = fftData[0..<40].reduce(0, +) * frequencyMultiplier * colorMultiplier
            let midsEnergy = fftData[40..<150].reduce(0, +) * frequencyMultiplier * colorMultiplier
            let trebleEnergy = fftData[150..<256].reduce(0, +) * frequencyMultiplier * colorMultiplier
            
            let red = UInt8(min(bassEnergy * 400 * brightnessMultiplier, 255))
            let green = UInt8(min(midsEnergy * 400 * brightnessMultiplier, 255))
            let blue = UInt8(min(trebleEnergy * 400 * brightnessMultiplier, 255))
            
            onColorValues(red, green, blue)
            logger.debug("FFT frequency analysis: R:\(red), G:\(green), B:\(blue)")
            
        case .colorWheel:
            let low = fftData[0..<85].reduce(0, +) * frequencyMultiplier * colorMultiplier
            let mid = fftData[85..<170].reduce(0, +) * frequencyMultiplier * colorMultiplier
            let high = fftData[170..<256].reduce(0, +) * frequencyMultiplier * colorMultiplier
            let total = low + mid + high
            
            let brightness = CGFloat(min(total * 200 * brightnessMultiplier, 1.0))
            let hue: CGFloat = low > mid && low > high ? 0.0 : mid > high ? 0.33 : 0.66
            let color = UIColor(hue: hue, saturation: 1, brightness: brightness, alpha: 1)
            
            guard let comp = color.cgColor.components else { return }
            let red = UInt8(comp[0] * 255)
            let green = UInt8(comp[1] * 255)
            let blue = UInt8(comp[2] * 255)
            
            onColorValues(red, green, blue)
            logger.debug("Color wheel analysis: R:\(red), G:\(green), B:\(blue)")
            
        default:
            break
        }
    }

}

class BeatDetector {
    private let logger = Logger(subsystem: "com.musiclightsync.audio", category: "BeatDetector")
    
    private var energyHistory = [Float]()
    private let historySize = 43
    private var lastBeatTime: TimeInterval = 0
    private var threshold: Float = 0.0
    private let minInterval: TimeInterval = 0.3
    private var beatSensitivity: Float = 1.0
    private var brightnessSensitivity: Float = 1.0

    init() {
        logger.info("BeatDetector initialized")
    }
    
    func updateBeatSensitivity(_ sensitivity: Float) {
        logger.info("Updating beat sensitivity to \(sensitivity)")
        beatSensitivity = sensitivity
    }
    
    func updateBrightnessSensitivity(_ sensitivity: Float) {
        logger.info("Updating brightness sensitivity to \(sensitivity)")
        brightnessSensitivity = sensitivity
    }

    func detectBeat(amplitude: Float, sensitivity: Float = 1.0) -> Bool {
        let now = Date().timeIntervalSince1970
        let adjustedAmplitude = amplitude * self.brightnessSensitivity
        let energy = adjustedAmplitude * adjustedAmplitude
        
        self.energyHistory.append(energy)
        if self.energyHistory.count > self.historySize { self.energyHistory.removeFirst() }
        guard self.energyHistory.count >= self.historySize else { return false }
        
        let average = self.energyHistory.dropLast().reduce(0,+)/Float(self.historySize - 1)
        self.threshold = average * (1.5 + self.beatSensitivity * 0.5)
        
        if energy > self.threshold && now - self.lastBeatTime > self.minInterval {
            self.lastBeatTime = now
            logger.debug("Beat detected with energy: \(energy), threshold: \(self.threshold)")
            return true
        }
        return false
    }
}
