import SwiftUI
import Speech
import AVFoundation
import MediaPlayer
import Combine

class SpeechRecognizer: ObservableObject {
    
    private let contentClass: ContentClass
    @AppStorage("playSoundSetting") var playSoundSetting: Bool = true

    init(contentClass: ContentClass) {
        self.contentClass = contentClass
        print("ContentClass instance in SpeechRecognizer: \(ObjectIdentifier(contentClass))")
    }

    @Published var isListening = false
    @Published var recognizedText = "" {
        didSet {
            onRecognizedTextUpdate?(recognizedText) // Notify external state of text updates
        }
    }
    var audioPlayer: AVAudioPlayer?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private var musicPlayerIsPlaying = false
    
    var onCommandDetected: (() -> Void)?
    var onRecognizedTextUpdate: ((String) -> Void)? // Closure for updating external state
    
    func toggleListening() {
        if isListening {
            print("Stop listening programmatically")
            stopListening()
        } else {
            print("Start listening programmatically")
            contentClass.hideKeyboard()
            startListening()
        }
    }

    func startListening() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.contentClass.scrollTop(proxy: self.contentClass.msgProxy)
                    self.startRecognition()
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition authorization denied or unavailable.")
                @unknown default:
                    print("Unknown authorization status.")
                }
            }
        }
    }
    
    func playSound() {
        if playSoundSetting {
            // Step 2: Stop the current player if it's playing
            if let player = audioPlayer, player.isPlaying {
                player.stop()
            }
            
            // Step 3: Create and play the sound
            if let soundURL = Bundle.main.url(forResource: "sound", withExtension: "mp3") {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    audioPlayer?.prepareToPlay()
                    audioPlayer?.play()
                } catch {
                    print("Failed to play sound: \(error.localizedDescription)")
                }
            } else {
                print("Sound file not found")
            }
        }
    
    }
    
    
    private func startRecognition() {
        // Play a tone to indicate listening
        //AudioServicesPlaySystemSound(1103) // "Tone" system sound
        playSound()
        if contentClass.musicPlayer.playbackState == .playing {
            contentClass.musicPlayerIsPlaying = true
        } else {
            contentClass.musicPlayerIsPlaying = false
        }

        if audioEngine.isRunning {
            stopListening()
        }

        print("start listening")
        contentClass.isListening(x: true)
        configureAudioSession()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                print("Recognized Text: \(result.bestTranscription.formattedString)")
                self.recognizedText = result.bestTranscription.formattedString
                self.resetSilenceTimer()
            }
            
            if let error = error {
                print("Recognition Error: \(error.localizedDescription)")
            }
            
            if result?.isFinal ?? false {
                print("Final Transcription: \(result?.bestTranscription.formattedString ?? "")")
                self.stopListening()
                self.sendCommandAfterPause()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        do {
            try startAudioEngine() // Use the existing startAudioEngine method
            isListening = true
            print("Audio engine started")
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        print("Stop Audio Engine")
        contentClass.isListening(x: false)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        contentClass.scrollToBottomBottom(proxy: contentClass.msgProxy)
        silenceTimer?.invalidate()
        reconfigureAudioSession()
        if contentClass.musicPlayerIsPlaying {
            contentClass.musicPlayer.play()
        }
        print("isListening \(isListening)")
    }
    
    private func startAudioEngine() throws {
        // Existing code for starting the audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.sendCommandAfterPause()
        }
    }
    
    private func sendCommandAfterPause() {
        guard !recognizedText.isEmpty else { return }
        stopListening() // Stop speech recognition after the pause
        onCommandDetected?()
    }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func reconfigureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(false)
            print("Audio session successfully configured for playback.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
