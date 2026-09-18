# MusicLightSync

MusicLightSync is an iOS app that listens to ambient audio through the device's microphone and drives a Bluetooth LE LED strip/light in real time, mapping amplitude, frequency content, and detected beats to color and brightness. It's built with SwiftUI and [AudioKit](https://github.com/AudioKit/AudioKit), and is designed to keep working reliably in the background and over car Bluetooth (CarPlay/hands-free audio) connections.

## Features

- **Real-time audio-reactive lighting** — analyzes live microphone input and streams RGB color updates to a BLE LED device as music plays.
- **Multiple visualization modes** — amplitude-based color, frequency-band (bass/mid/treble → RGB) mapping, and a hue-rotating "color wheel" mode driven by FFT energy.
- **Beat detection** — a simple energy-history beat detector triggers flash/pulse events on musical beats, with an adjustable sensitivity control.
- **Tunable sensitivity controls** — Music Brightness, Color Sensitivity, Beat Response, and Frequency Response sliders, persisted across launches via `UserDefaults`.
- **Manual LED control** — pick a static color (custom color picker or presets), and choose an animated pattern (Static, Fade, Flash, Color Wheel) with adjustable brightness and speed, independent of music sync.
- **Bluetooth LE device management** — scans for nearby BLE peripherals, connects, and automatically attempts reconnection (with exponential backoff) if the connection drops unexpectedly.
- **Background & car resilience** — configured with `audio` and `bluetooth-central` background modes, restores BLE state after the app is suspended, and recovers automatically from `AVAudioSession` interruptions (e.g. phone calls) and audio route changes (e.g. connecting/disconnecting from a car).
- **Bluetooth audio quality preservation** — explicitly binds capture to the built-in microphone so that connecting to a car's Bluetooth audio doesn't force the whole system down from high-quality A2DP streaming to low-quality HFP (mono, phone-call quality) audio.
- **Cyberpunk-styled UI** — a themeable SwiftUI design system (`ThemeManager`/`AppTheme`) currently shipping a dark "Cyberpunk" theme.

## Why microphone input?

iOS sandboxing and DRM protections mean apps cannot tap into another app's audio output (e.g. Apple Music, Spotify) or the system audio bus directly. MusicKit and ReplayKit do not expose a general-purpose, real-time PCM stream suitable for this use case, and third-party streaming APIs (e.g. Spotify's audio-analysis endpoints) have been deprecated. MusicLightSync therefore analyzes audio the same way most music-reactive light products do: by listening through the microphone, which works with any audio source (any app, any streaming service, or even live music) without special integrations.

## Architecture

The app follows a lightweight MVVM structure built on `ObservableObject`/`@EnvironmentObject`:

```
MusicLightSync/
├── MusicLightSyncApp.swift      # App entry point; configures the shared AVAudioSession
├── ContentView.swift             # Root view; wires components together and owns sync toggle
├── AudioAnalyzer.swift           # Microphone capture, FFT/amplitude analysis, beat detection
├── BLEManager.swift               # CoreBluetooth central manager, device scan/connect/reconnect
├── Theme.swift                    # Theme protocol + ThemeManager + design tokens
└── Components/
    ├── HeaderView.swift
    ├── DeviceConnectionView.swift     # BLE scan/connect UI + connection status
    ├── MusicSensitivityView.swift     # Sensitivity sliders (brightness/color/beat/frequency)
    └── LEDControlsView.swift          # Manual color picker, brightness/speed, pattern selection
```

Two areas of core logic are deliberately factored out into pure, stateless enums so they're unit-testable without a live audio/BLE stack:

- **`AudioColorMapper`** (in `AudioAnalyzer.swift`) — pure functions that convert amplitude/FFT band energy into RGB values.
- **`BLECommandBuilder`** (in `BLEManager.swift`) — pure functions that encode RGB/pattern/brightness/speed values into the raw BLE byte packets, plus the reconnect backoff schedule.

### BLE protocol

MusicLightSync speaks a common generic-LED-controller BLE protocol (the same one used by many inexpensive "magic home"-style RGB/RGBIC controllers). Commands are raw byte arrays framed with `0x7E` ... `0xEF`:

| Command | Format |
|---|---|
| Set RGB color | `[0x7E, 0x07, 0x05, 0x03, R, G, B, 0x10, 0xEF]` |
| Pattern (fade/flash/color wheel/static) | `[0x7E, 0x04, 0x04, <pattern>, <brightness>, <speed>, 0x01, 0xFF, 0x00, 0xEF]` |

Brightness and speed are clamped and scaled to `UInt8` before encoding (see `BLECommandBuilder.patternCommand`). The app discovers the first writable characteristic on any connected peripheral and writes to it — no fixed service/characteristic UUID is required, so it should work with most controllers implementing this protocol.

## Requirements

- Xcode 16+ (project targets iOS 18.2)
- iOS 18.2+ device (real hardware recommended — microphone input and CoreBluetooth do not work in the iOS Simulator)
- A BLE LED controller that implements the command protocol described above
- [AudioKit](https://github.com/AudioKit/AudioKit) 5.6.5+ (resolved automatically via Swift Package Manager)

## Getting started

1. Clone the repository:
   ```sh
   git clone https://github.com/OptimusRahul/MusicLightSync.git
   cd MusicLightSync
   ```
2. Open `MusicLightSync.xcodeproj` in Xcode. Swift Package Manager will resolve the AudioKit dependency automatically.
3. Select your development team under the app target's Signing & Capabilities tab.
4. Build and run (`Cmd+R`) on a physical iOS device.
5. Grant Bluetooth and microphone permissions when prompted.
6. From the app: tap **Scan for Devices**, select your LED controller, then tap **Start Music Sync** to begin reacting to ambient audio, or use the **LED Controls** section to set colors/patterns manually.

## Testing

Core logic is covered by unit tests written with Swift Testing (`XCTest`'s successor, using `@Test`), located in `MusicLightSyncTests/`:

- `AudioColorMapperTests.swift` — amplitude/frequency-to-color mapping and clamping behavior
- `BeatDetectorTests.swift` — beat-detection threshold and sensitivity behavior
- `BLECommandBuilderTests.swift` — BLE packet encoding and reconnect backoff
- `PatternCodableTests.swift` — `Codable` conformance for LED presets/patterns

Run the suite in Xcode with `Cmd+U`, or from the command line:

```sh
xcodebuild test -project MusicLightSync.xcodeproj -scheme MusicLightSync -destination 'platform=iOS Simulator,name=iPhone 16'
```

(The unit tests exercise pure logic only, so they run fine in the simulator even though the live app does not.)

## Known limitations

- Requires a physical device — the simulator has no microphone input and no real CoreBluetooth radio.
- Only tested against generic BLE RGB/RGBIC controllers using the `0x7E`/`0xEF`-framed protocol described above; controllers using a different protocol will need a new command builder.
- Because analysis is microphone-based, ambient noise and speaker/mic placement affect responsiveness — this is an inherent tradeoff of not having direct access to the app's own audio stream (see [Why microphone input?](#why-microphone-input)).

## License

No license has been specified yet — all rights reserved by the author unless/until one is added.
