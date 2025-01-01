import AVFoundation
import SwiftUI

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private let contentClass: ContentClass
    @Published var isPlaying: Bool = false
    @AppStorage("playSoundSetting") var playSoundSetting: Bool = true
    private var audioPlayer: AVAudioPlayer?
    weak var speechRecognizer: SpeechRecognizer?
    
    init(contentClass: ContentClass) {
        self.contentClass = contentClass
        super.init()
    }
    
    deinit {
        print("AudioPlayerManager deinitialized")
        stop()
    }
    
    
    func setSpeechRecognizer(_ recognizer: SpeechRecognizer) {
        self.speechRecognizer = recognizer
    }
    
    func playSound() {
        guard playSoundSetting else {
            print("App Sounds turned off")
            speechRecognizer?.checkPermission()
            return
        }
        
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        AudioSessionManager.shared.configureForDefaultAudio()

        guard let url = Bundle.main.url(forResource: "sound", withExtension: "mp3") else {
            print("Audio file not found")
            contentClass.setShowAlert(true)  // Notify user via UI
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            play()
        } catch {
            print("Error initializing audio player: \(error)")
            contentClass.setShowAlert(true)  // Notify user via UI
        }
    }


    func play() {
        print("playing sound...")
        audioPlayer?.play()
        isPlaying = true
    }

    func stop() {
        audioPlayer?.stop()
        isPlaying = false
    }

    // MARK: - AVAudioPlayerDelegate Methods

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Playback Finished: \(flag ? "Success" : "Failure")")
        isPlaying = false
        //stop()
        AudioSessionManager.shared.resetAudioSession()
        speechRecognizer?.checkPermission()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio Player Decode Error: \(error.localizedDescription)")
            contentClass.setShowAlert(true)
        }
    }
}
