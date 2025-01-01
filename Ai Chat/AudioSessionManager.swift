import AVFoundation

class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()

    @Published var isInterrupted = false
    @Published var currentRoute: String = "Unknown"

    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {
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

        updateCurrentRoute(AVAudioSession.sharedInstance().currentRoute)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        print("AudioSessionManager deinitialized")
    }

    func configureForSpeechRecognition() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session configured for Speech Recognition")
        } catch {
            print("Error configuring audio session: \(error.localizedDescription)")
        }
    }
    
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


    func configureForDefaultAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session configured for Default Audio")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func resetAudioSession() {
        do {
            stopAudioEngine()
            stopSynthesizer()
            try AVAudioSession.sharedInstance().setActive(false)
            print("Audio session reset successfully")
        } catch {
            print("Failed to reset audio session: \(error.localizedDescription)")
        }
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("Audio engine stopped")
        }
    }

    private func stopSynthesizer() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("Speech synthesizer stopped")
        }
    }

    private func updateCurrentRoute(_ route: AVAudioSessionRouteDescription) {
        currentRoute = route.outputs.first?.portName ?? "No Output Available"
        print("Current audio route: \(currentRoute)")
    }

    @objc private func handleInterruption(notification: Notification) {
        // Handle interruption as implemented earlier
    }

    @objc private func handleRouteChange(notification: Notification) {
        // Handle route change as implemented earlier
    }
}
