import SwiftUI
import Speech
import AVFoundation
import MediaPlayer
import Combine

class SpeechRecognizer: ObservableObject {
    
    private let contentClass: ContentClass
    private let audioPlayerManager: AudioPlayerManager

    init(contentClass: ContentClass, audioPlayerManager: AudioPlayerManager) {
        self.contentClass = contentClass
        self.audioPlayerManager = audioPlayerManager
    }

    @Published var isListening = false
    @Published var recognizedText = "" {
        didSet {
            onRecognizedTextUpdate?(recognizedText) // Notify external state of text updates
        }
    }

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest? // Optional for proper reinitialization
    private var recognitionTask: SFSpeechRecognitionTask?
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
        print("Preparing to start listening...")
        audioPlayerManager.playSound()
    }
    
    func checkPermission() {
        // Check and remove any existing taps before adding a new one
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        // Request authorization for speech recognition
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch authStatus {
                case .authorized:
                   // self.contentClass.scrollTop(proxy: self.contentClass.msgProxy)
                   
                    self.checkMic()
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition authorization denied or unavailable.")
                @unknown default:
                    print("Unknown authorization status.")
                }
            }
        }
    }

    func checkMic() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if granted {
                    print("Microphone permission granted")
                    self.startRecognition()
                } else {
                    print("Microphone permission denied.")
                }
            }
        }
        
    }
    
    private func startRecognition() {
        isListening = true
        
        // Clean up any existing audio engine state
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        AudioSessionManager.shared.configureForSpeechRecognition()
        
        print("Starting Recognition...")

        // Initialize recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0) // Get the input node's format
        print("Sample Rate: \(format.sampleRate), Channels: \(format.channelCount)")
        if (format.channelCount == 0) {
            print("Failed to start audio engine")
            return
        }
        let inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        let audioFormat = AVAudioFormat(commonFormat: inputFormat.commonFormat,
                                        sampleRate: inputFormat.sampleRate,
                                        channels: inputFormat.channelCount,
                                        interleaved: inputFormat.isInterleaved)

        // Add input tap
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
        }


        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("Audio Engine Started")
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
            return
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                print("Recognized Text: \(result.bestTranscription.formattedString)")
                self.recognizedText = result.bestTranscription.formattedString
                self.resetSilenceTimer()
            }

            if let error = error {
                print("Recognition Error: \(error.localizedDescription)")
                self.stopListening()
                return
            }

            if result?.isFinal ?? false {
                print("Final Transcription: \(result?.bestTranscription.formattedString ?? "")")
                self.stopListening()
                self.sendCommandAfterPause()
            }
        }

        print("Listening started...")
        contentClass.isListening(x :true)
    }
    
    func stopListening() {
        print("Stop Audio Engine")
        // Reset audio session
        AudioSessionManager.shared.resetAudioSession()
        contentClass.isListening(x: false)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil // Clean up the request
        isListening = false
        //contentClass.scrollToBottom(proxy: contentClass.msgProxy)
        silenceTimer?.invalidate()

        if contentClass.musicPlayerIsPlaying {
            contentClass.musicPlayer.play()
        }
        print("isListening \(isListening)")
    }
    
    private func startAudioEngine() throws {
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
    
}
