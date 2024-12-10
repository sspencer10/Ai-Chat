//
//  MenuButton.swift
//  Chat with Ai Plus
//
//  Created by Steven Spencer on 12/9/24.
//

import Foundation
import SwiftUI

struct MenuButton: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var contentClass: ContentClass
    @ObservedObject var speechRecognizer: SpeechRecognizer // Changed to @ObservedObject
    @ObservedObject var speechSynthesizer: SpeechSynthesizer // Changed to @ObservedObject
    @State private var isShowingSettings = false
    @State private var isShowingSessions = false
    
    init(contentClass: ContentClass, speechRecognizer: SpeechRecognizer, speechSynthesizer: SpeechSynthesizer) {
        self.contentClass = contentClass
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
    }
    var body: some View {
        Menu {
            Button(action: { contentClass.startNewSession() }) {
                Label("New Session", systemImage: "plus.circle")
            }
            
            Button(action: { isShowingSessions = true }) {
                Label("Load Session", systemImage: "tray.and.arrow.down")
            }
            
            Button(action: { isShowingSettings = true }) {
                Label("Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "line.horizontal.3")
                .padding()
                .font(.system(size: 20))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.top, 20)
        }
        .onTapGesture {
            contentClass.hideKeyboard()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(selectedModel: contentClass.$selectedModel, selectedVoice: speechSynthesizer.$selectedVoice, isSpeechEnabled: contentClass.$isSpeechEnabled)
            //SettingsView(selectedModel: contentClass.$selectedModel, isSpeechEnabled: contentClass.$isSpeechEnabled)
        }
        .sheet(isPresented: $isShowingSessions) {
            ChatSessionsView { selectedSession in
                contentClass.loadSession(selectedSession)
            }
        }
    }
}
