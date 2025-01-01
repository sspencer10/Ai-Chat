import SwiftUI
import Speech
import AVFoundation
import Down
import UIKit
import Foundation
import CoreData
import Photos
import WebKit


struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var contentClass: ContentClass
    @ObservedObject var speechRecognizer: SpeechRecognizer // Changed to @ObservedObject
    @ObservedObject var speechSynthesizer: SpeechSynthesizer // Changed to @ObservedObject
    @StateObject var userDefaultsManager = UserDefaultsManager()
    @State private var isShowingSettings = false
    @State private var isShowingSessions = false
    @State private var showCopiedToast = false
    @State private var isTyping = false
    @State private var isAtBottom = true
    @State var command: String = ""
    @State var webSearch: Bool = false
    @State var uploadSwitch: Bool = false
    
    @State private var loadedImage: UIImage? = nil
    @State private var showShareOptions: Bool = false
    @State private var shareItems: [Any]? = nil
    @State private var pdfGenerator: PDFGenerator? = nil // Retain PDFGenerator instance
    // State variables for alerts
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var selectedFile: URL?
    @State var showFilePicker: Bool = false
    @State var fileName: String = ""
    @State var showContacts: Bool = false
    
    
    
    init(contentClass: ContentClass, speechRecognizer: SpeechRecognizer, speechSynthesizer: SpeechSynthesizer) {
        self.contentClass = contentClass
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
    }
    var session: ChatSession?  // Optional session to load
    
    var body: some View {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            VStack {
                mainContentWithMenu
            }
        } else {
            NavigationView {
                ZStack {
                    Color.clear
                    mainContentWithMenu
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(
                    selectedModel: contentClass.$selectedModel,
                    selectedVoice: speechSynthesizer.$selectedVoice,
                    isSpeechEnabled: contentClass.$isSpeechEnabled
                )
            }
            .sheet(isPresented: $isShowingSessions) {
                ChatSessionsView { selectedSession in
                    contentClass.loadSession(selectedSession)
                }
            }
            .onChange(of: userDefaultsManager.showCopiedToast) {
                showCopiedToast = userDefaultsManager.showCopiedToast
            }
            .onAppear {
                showCopiedToast = userDefaultsManager.showCopiedToast
            }
        }
    }
    
    private var mainContentWithMenu: some View {
        MainContent(
            contentClass: contentClass,
            speechRecognizer: speechRecognizer,
            speechSynthesizer: speechSynthesizer
        )
        .navigationBarItems(trailing: VStack {
            MenuButton(
                contentClass: contentClass,
                speechRecognizer: speechRecognizer,
                speechSynthesizer: speechSynthesizer
            )
            .padding(.bottom, 10)
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(contentClass: ContentClass(), speechRecognizer: SpeechRecognizer(contentClass: ContentClass(), audioPlayerManager: AudioPlayerManager(contentClass: ContentClass())), speechSynthesizer: SpeechSynthesizer(contentClass: ContentClass()))
    }
}


