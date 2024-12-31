import AVFoundation

class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()
    
    @Published var isInterrupted = false
    @Published var isRouteChanged = false
    @Published var currentRoute: String = "Unknown"
    

    
    // Add the missing audio components
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    
    private init() {
        // Add observers for interruptions and route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        let audioSession = AVAudioSession.sharedInstance()
        updateCurrentRoute(audioSession.currentRoute)

    }
    
    
    
    /// Configure the audio session for Speech Recognition
    func configureForSpeechRecognition() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio Session configured for Speech Recognition")
        } catch {
            print("Failed to configure audio session for Speech Recognition: \(error.localizedDescription)")
        }
    }
    
    /// Configure the audio session for Default Audio
    func configureForDefaultAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio Session configured for Default Audio")
        } catch {
            print("Failed to configure audio session for Default Audio: \(error.localizedDescription)")
        }
    }
    
    /// Configure the audio session for Speech Synthesis
    func configureForSpeechSynthesis() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio Session configured for Speech Synthesis")
        } catch {
            print("Failed to configure audio session for Speech Synthesis: \(error.localizedDescription)")
        }
    }
    
    func resetAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        if isInterrupted {
            print("Audio session currently interrupted, delaying deactivation.")
            return
        }
        
        if audioSession.isOtherAudioPlaying {
            print("Other audio is playing, delaying deactivation.")
            return
        }
        
        do {
            // Stop active components (e.g., SpeechSynthesizer or AudioEngine)
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
            
            try audioSession.setActive(false)
            print("Audio Session reset successfully")
        } catch {
            print("Failed to reset audio session: \(error.localizedDescription)")
        }
    }
    
    private func updateCurrentRoute(_ route: AVAudioSessionRouteDescription) {
        if let output = route.outputs.first {
            currentRoute = output.portName
        } else {
            currentRoute = "Unknown"
        }
    }
    
    // MARK: - Handle Interruptions
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio session interrupted
            isInterrupted = true
            print("Audio Session was interrupted")
        case .ended:
            // Audio session interruption ended, reactivate session
            isInterrupted = false
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                print("Audio Session interruption ended and reactivated")
            } catch {
                print("Failed to reactivate audio session: \(error.localizedDescription)")
            }
        @unknown default:
            print("Unknown audio session interruption type")
        }
    }
    
    // MARK: - Handle Route Changes
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            print("New audio device available (e.g., headphones connected)")
            isRouteChanged = true
        case .oldDeviceUnavailable:
            print("Previous audio device removed (e.g., headphones disconnected)")
            isRouteChanged = true
        case .categoryChange:
            print("Audio session category changed")
        default:
            print("Audio route changed for another reason \(reasonValue)")
        }
    }
}
