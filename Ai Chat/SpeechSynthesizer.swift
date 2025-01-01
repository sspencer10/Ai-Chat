//
//  SpeechSynthesizer.swift
//  Chat with Ai Plus
//
//  Created by Steven Spencer on 12/8/24.
//

import Foundation
import SwiftUI
import Speech
import MediaPlayer

class SpeechSynthesizer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    private let contentClass: ContentClass
    @AppStorage("selectedVoice") var selectedVoice = "com.apple.ttsbundle.siri_male_en-US_compact"
    var synthesizer = AVSpeechSynthesizer()
    
    init(contentClass: ContentClass) {
        self.contentClass = contentClass
        super.init()
        synthesizer.delegate = self
    }
    

    
    // Delegate methods
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("Speech started!")
        if contentClass.musicPlayer.playbackState == .playing {
            contentClass.musicPlayerIsPlaying = true
            contentClass.musicPlayer.pause()
        } else {
            contentClass.musicPlayerIsPlaying = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Speech finished!")
        stopSpeech()
        if (contentClass.musicPlayerIsPlaying) {
            contentClass.musicPlayer.play()
        }


    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("Speech paused")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("Speech continued")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Speech canceled")
    }
    
    func speakResponse(response: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        AudioSessionManager.shared.configureForSpeechSynthesis()
        print("speaking response")
        
        // Extract the first paragraph before the first newline character
        let firstParagraph = response.components(separatedBy: "\n").first ?? response
        
        let utterance = AVSpeechUtterance(string: firstParagraph)
        utterance.volume = 1.0 // Maximum volume
        
        // Use the selected voice if available, otherwise default to English (US)
        if let voice = AVSpeechSynthesisVoice(identifier: selectedVoice) {
            utterance.voice = voice
        } else {
            print("Selected voice identifier is invalid. Falling back to default voice.")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
         
        //utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        // Speak the extracted first paragraph
        synthesizer.speak(utterance)
    }


    // Function to stop speech immediately
    func stopSpeech() {
        print("Stopping speech")
        synthesizer.stopSpeaking(at: .immediate) // Stops immediately
        AudioSessionManager.shared.resetAudioSession()
    }
}
