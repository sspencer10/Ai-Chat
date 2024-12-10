//
//  SettingsView.swift
//  Ai Chat
//
//  Created by Steven Spencer on 10/30/24.
//

import Foundation
import SwiftUI
import AVFoundation

struct SettingsView: View {
    @StateObject var userDefaultsManager = UserDefaultsManager()
    @Binding var selectedModel: String
    @Binding var selectedVoice: String
    @Binding var isSpeechEnabled: Bool
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
    @AppStorage("playSoundSetting") var playSoundSetting: Bool = true

    @Environment(\.presentationMode) var presentationMode  // Used to dismiss the view

    let models = ["gpt-3.5-turbo-0125", "gpt-4o-mini"]  // Available models
    
    let predefinedVoices = [
        "com.apple.ttsbundle.Samantha-compact": "Samantha",
        "com.apple.ttsbundle.siri_female_en-US_compact": "Nicky",
        "com.apple.ttsbundle.siri_male_en-US_compact": "Aaron"
    ]  // Predefined voices

    // Get only the enhanced voices in English (en-US)
    var enhancedVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("en") && voice.quality != .default
        }
    }
     

    let themes = ["Light", "Dark", "System"]  // Appearance options
    let appearanceModes = AppearanceMode.allCases // Array of available modes

    var body: some View {
        NavigationView {
            Form {
                // Appearance Section
                Section(header: Text("Appearance")) {
                    List(appearanceModes, id: \.self) { mode in
                        HStack {
                            Text(mode.rawValue.capitalized)
                            Spacer()
                            if mode == appearanceMode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appearanceMode = mode // Set the selected mode
                        }
                    }
                }

                // GPT Model Section
                Section(header: Text("GPT Model")) {
                    List(models, id: \.self) { model in
                        HStack {
                            Text(model)
                            Spacer()
                            if model == selectedModel {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedModel = model  // Set the selected model
                        }
                    }
                }
                
                Section(header: Text("Costs")) {
                    Text("Price for last request: $\(UserDefaults.standard.string(forKey: "cost") ?? "")")
                    Text("Total Spent: $\(String(format: "%.2f", UserDefaults.standard.double(forKey: "totalSpent")))")
                }
                
                // Speech Enable/Disable Section
                Section(header: Text("App Sounds")) {
                    Toggle(isOn: $playSoundSetting) {
                        Text("Enable App Sounds")
                    }
                }
                
                // Speech Enable/Disable Section
                Section(header: Text("Text-to-Speech")) {
                    Toggle(isOn: $isSpeechEnabled) {
                        Text("Enable Speech")
                    }
                }

                // Conditionally show Voice selection if speech is enabled
                
                if isSpeechEnabled {
                    Section(header: Text("Text-to-Speech Voice")) {
                        // Display predefined voices
                        List(predefinedVoices.keys.sorted(), id: \.self) { voiceKey in
                            HStack {
                                Text(predefinedVoices[voiceKey] ?? "")
                                Spacer()
                                if voiceKey == selectedVoice {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVoice = voiceKey  // Set the selected voice
                            }
                        }

                        // Display enhanced voices, if any
                        if !enhancedVoices.isEmpty {
                                List(enhancedVoices, id: \.identifier) { voice in
                                    HStack {
                                        Text("\(voice.name)")
                                        Spacer()
                                        if voice.identifier == selectedVoice {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedVoice = voice.identifier  // Set the selected enhanced voice
                                    }
                                }
                        }

                        // Mention that other voices are available in the Settings app
                        Text("Other voices are available in Settings > Accessibility > Spoken Content > Voices.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                 
            }

#if !os(macOS)
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()  // Dismiss the view
            })
#endif
        }
    }
}

