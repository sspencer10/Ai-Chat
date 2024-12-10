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
        print("ContentClass instance in SpeechSynthesizer: \(ObjectIdentifier(contentClass))")
        super.init()
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
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
        let audioSession = AVAudioSession.sharedInstance()

        try? audioSession.setActive(false)
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
        let audioSession = AVAudioSession.sharedInstance()

        try? audioSession.setActive(true)
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


    // Handle interruptions
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .began {
            // Pause or stop speech
            if synthesizer.isSpeaking {
                synthesizer.pauseSpeaking(at: .word)
            }
        } else if type == .ended {
            // Resume speech if appropriate
            synthesizer.continueSpeaking()
        }
    }

    // Handle route changes
    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            // Bluetooth device disconnected
            if synthesizer.isSpeaking {
                synthesizer.pauseSpeaking(at: .word)
            }
        case .newDeviceAvailable:
            // Bluetooth device connected
            // Optionally resume speech
            break
        default:
            break
        }
    }
    // Function to stop speech immediately
    func stopSpeech() {
        print("Stopping speech")
        synthesizer.stopSpeaking(at: .immediate) // Stops immediately
    }
}
