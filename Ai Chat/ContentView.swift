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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject var contentClass: ContentClass
    @ObservedObject var speechRecognizer: SpeechRecognizer // Changed to @ObservedObject
    @ObservedObject var speechSynthesizer: SpeechSynthesizer // Changed to @ObservedObject
    @ObservedObject var keyboardResponder: KeyboardResponder // Changed to @ObservedObject
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
    @State private var text: String = ""
    @State var scrollOffset: CGFloat = 0.0 // Track the current scroll position
    @State private var height: CGFloat = 50
    @State private var lastScrollOffset: CGFloat = 0.0 // Track the last scroll offset
    //@ObservedObject private var keyboard = KeyboardResponder()
    @State private var proxy: ScrollViewProxy? = nil



    init(contentClass: ContentClass, speechRecognizer: SpeechRecognizer, speechSynthesizer: SpeechSynthesizer, keyboardResponder: KeyboardResponder) {
        self.contentClass = contentClass
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
        self.keyboardResponder = keyboardResponder
    }
    var session: ChatSession?  // Optional session to load
    
    var body: some View {
        
        
        if ProcessInfo.processInfo.isiOSAppOnMac {
            VStack {
                contentOnMac
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(MenuButton(contentClass: contentClass, speechRecognizer: speechRecognizer, speechSynthesizer: speechSynthesizer), alignment: .topTrailing)
                    .sheet(isPresented: $isShowingSettings) {
                        SettingsView(selectedModel: contentClass.$selectedModel, selectedVoice: speechSynthesizer.$selectedVoice, isSpeechEnabled: contentClass.$isSpeechEnabled)
                        //SettingsView(selectedModel: contentClass.$selectedModel, isSpeechEnabled: contentClass.$isSpeechEnabled)
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
        } else {
            NavigationView {
                ZStack {
                    Color.clear
                    MainContent(contentClass: contentClass, speechRecognizer: speechRecognizer, speechSynthesizer: speechSynthesizer, keyboardResponder: keyboardResponder)
                        .navigationBarItems(trailing: MenuButton(contentClass: contentClass, speechRecognizer: speechRecognizer, speechSynthesizer: speechSynthesizer))
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
            .onChange(of: userDefaultsManager.showCopiedToast) {
                showCopiedToast = userDefaultsManager.showCopiedToast
            }
            .onAppear {
                showCopiedToast = userDefaultsManager.showCopiedToast
                print("ContentClass instance in ContentView: \(ObjectIdentifier(contentClass))")
            }
 
        }
    }
    
    var contentOnMac: some View {
        VStack {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                //showCopiedToast = false
                                UserDefaults.standard.set(false, forKey: "showCopiedToast")
                            }
                        }
                    }
                    .padding(.bottom, 0)
            } else {
                Text("\(contentClass.selectedModel)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) { // Adjusted spacing between messages
                        if !contentClass.isDeviceListening {
                            ForEach(contentClass.messages) { message in
                                MessageViewOnMac(message: message, contentClass: contentClass)
                            }
                        } else {
                            Spacer()
                            Spacer()
                            PulsingMicrophoneView(contentClass: contentClass, speechRecognizer: speechRecognizer, speechSynthesizer: speechSynthesizer)
                        }
                    }
                    .padding()
                }
                .padding()
                .padding(.top, 20)
                .onChange(of: contentClass.messages.count) {
                    if let lastMessage = contentClass.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Typing indicator, shown when the assistant is typing
            if contentClass.isTyping {
                TypingIndicatorView()
                    .transition(.opacity)
                    .padding(.bottom, 10)
            }
            
            inputAreaOnMac
        }
        .padding(.top, 15)
        .navigationBarTitle("AI Chat", displayMode: .inline)
        .onAppear {
            /*
             if let session = session {
             loadSession(session)
             }
             */
        }
    }
    
    var inputAreaOnMac: some View {
        VStack {
            HStack(spacing: 8) {
                ZStack(alignment: .topTrailing) { // Align microphone to the top-right
                    // Background for TextEditor
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                        .frame(height: max(height, 40)) // Matches TextEditor height
                    
                    // Placeholder and TextEditor
                    ZStack(alignment: .topLeading) { // Align placeholder to the top-left
                        // Placeholder
                        if contentClass.command.isEmpty {
                            Text(webSearch ? "Have AI search the web..." : "Enter your question...")
                                .foregroundColor(.gray)
                                .padding(.leading, 14) // Align with text inside TextEditor
                                .padding(.top, 12) // Align with vertical padding of TextEditor
                        }
                        
                        
                        TextEditor(text: $contentClass.command)
                            .frame(height: max(height, 50)) // Matches TextEditor height
                            .padding(.leading, 10)
                            .padding(.trailing, 40) // Reserve space for the microphone button
                            .background(Color.clear) // Transparent, so RoundedRectangle shows through
                            .scrollContentBackground(.hidden) // Ensure background takes effect
                            .onChange(of: contentClass.command) { // Updated for iOS 17
                                adjustHeight()
                            }
                    }
                    
                    // Microphone Button
                    Button(action: {
                        if speechRecognizer.isListening {
                            print("Stop")
                            speechRecognizer.stopListening()
                        } else {
                            print("Start")
                            speechRecognizer.startListening()
                        }                    }) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18))
                                .padding(12)
                                .foregroundColor(speechRecognizer.isListening ? .red : .gray.opacity(0.7))
                        }
                        .padding(.trailing, 1) // Ensure microphone stays inside the text area
                }
                .frame(maxWidth: .infinity)
                
                // Send Button
                Button(action: {
                    contentClass.sendCommand(isUpload: userDefaultsManager.isUpload)
                    contentClass.command = ""
                    if userDefaultsManager.isUpload {
                        uploadFile(fileNameInDocuments: fileName)
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .padding(11)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(.trailing, 8)
            }
            .padding(.horizontal)
            .padding(.top)
        
            // Second Row
            HStack {
                
                Button(action: {
                    showFilePicker = true
                })
                {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 19)).bold()
                        .padding(10)
                    //.background(showFilePicker || userDefaultsManager.isUpload ? Color.red : Color.blue)
                        .foregroundColor(showFilePicker || userDefaultsManager.isUpload ? Color.red : Color.blue)
                    //.clipShape(Circle())
                        .offset(y: -10)
                }
                .padding(.horizontal, 5)
                .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.json]) { result in
                    switch result {
                    case .success(let url):
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            
                            do {
                                // Read the JSON file as Data
                                let data = try Data(contentsOf: url)
                                
                                // Convert the Data to a JSON String
                                if let jsonString = String(data: data, encoding: .utf8) {
                                    print("JSON String: \(jsonString)")
                                    
                                    // Save the JSON String to UserDefaults
                                    fileName = url.lastPathComponent
                                    UserDefaults.standard.set(jsonString, forKey: "uploadedJSON")
                                    UserDefaults.standard.set(true, forKey: "isUpload")
                                    print("JSON saved to UserDefaults under 'uploadedJSON' key.")
                                } else {
                                    print("Failed to convert JSON Data to String.")
                                }
                                
                                // Prepare destination URL in Documents directory
                                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                                let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                                
                                // Overwrite the file if it already exists
                                if FileManager.default.fileExists(atPath: destinationURL.path) {
                                    try FileManager.default.removeItem(at: destinationURL)
                                    print("Existing file removed: \(destinationURL)")
                                }
                                
                                // Copy the file to the destination
                                try FileManager.default.copyItem(at: url, to: destinationURL)
                                print("File copied to local directory: \(destinationURL)")
                            } catch {
                                print("Error reading or copying file: \(error.localizedDescription)")
                            }
                        } else {
                            print("Failed to access the security-scoped resource.")
                        }
                    case .failure(let error):
                        print("File selection error: \(error.localizedDescription)")
                    }
                }
                // Web Search Button
                Button(action: {
                    webSearch.toggle()
                    UserDefaults.standard.set(webSearch, forKey: "webSearch")
                })
                {
                    Image(systemName: "network")
                        .font(.system(size: 19))
                        .padding(10)
                    //.background(webSearch ? Color.red : Color.blue)
                        .foregroundColor(webSearch ? Color.red : Color.blue)
                    //.clipShape(Circle())
                        .offset(y: -8)
                }
                // Mute
                Button(action: {
                    if contentClass.isSpeechEnabled {
                        contentClass.isSpeechEnabled = false
                        contentClass.stopSpeechIfNeeded()
                    } else {
                        contentClass.isSpeechEnabled = true
                    }
                }) {
                    Image(systemName: contentClass.isSpeechEnabled ? "speaker.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 19))
                        .padding(10)
                    //.background(webSearch ? Color.red : Color.blue)
                        .foregroundColor(contentClass.isSpeechEnabled ? .blue : .red) // Optional: color indication
                    //.clipShape(Circle())
                        .offset(y: -8)
                }
                .buttonStyle(.plain) // Removes any default button styling
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .sheet(isPresented: $showContacts) {
                ContactsView(contentClass: contentClass)
            }
            
        }
        .onChange(of: speechRecognizer.recognizedText) {
            contentClass.command = speechRecognizer.recognizedText
        }
        .onChange(of: userDefaultsManager.webSearch) {
            webSearch = userDefaultsManager.webSearch
        }
        .onChange(of: userDefaultsManager.showContacts) {
            showContacts = userDefaultsManager.showContacts
            //print("showContacts = \(showContacts)")
        }
        .onChange(of: showContacts) {
            if !showContacts {
                UserDefaults.standard.set(false, forKey: "showContacts")
            }
        }
        .onAppear {
            UserDefaults.standard.set(false, forKey: "showContacts")
            speechRecognizer.onCommandDetected = {
                contentClass.sendCommand(isUpload: userDefaultsManager.isUpload)
                contentClass.command = ""
            }
            webSearch = userDefaultsManager.webSearch
        }
        
        //.frame(maxWidth: 1000)
        .padding(.vertical, 1)
        .background(Color(.systemGray6))
        //.ignoresSafeArea(edges: .bottom)
        .onTapGesture {
            //contentClass.hideKeyboard()
        }
        
    }
    private func adjustHeight() {
        let lineHeight: Int = 22 // Approximate height of one line of text
        let maxLines: Int = 3
        let lines = contentClass.command.components(separatedBy: .newlines).count
        let contentHeight = CGFloat(lines * lineHeight)
        if contentHeight < CGFloat(maxLines * lineHeight) {
            height = contentHeight
        } else {
            height = CGFloat(66)
        }
        
    }

    func uploadFile(fileNameInDocuments: String) {
        // Prepare the file URL in the Documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileNameInDocuments)
        let serverURL = "https://www.sspencer10.com/ai/upload/index.php"
        // Check if the file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist at path: \(fileURL.path)")
            return
        }
        
        // Create the request
        guard let url = URL(string: serverURL) else {
            print("Invalid server URL.")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create the multipart/form-data body
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Generate the body
        var body = Data()
        
        // Append file data
        if let fileData = try? Data(contentsOf: fileURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileNameInDocuments)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        } else {
            print("Failed to read file data.")
            return
        }
        
        // End the body
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Set the body
        request.httpBody = body
        
        // Perform the upload task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error uploading file: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Server responded with status code: \(httpResponse.statusCode)")
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Server response: \(responseString)")
            }
        }
        fileName = ""
        
        task.resume()
    }
}


  
// Custom PreferenceKey for tracking scroll offset
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollViewOffset: ViewModifier {
    let coordinateSpace: String
    var onScroll: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .named(coordinateSpace)).minY) { newValue, oldValue in
                            onScroll(newValue)
                        }
                }
            )
    }
}

extension View {
    func trackScrollOffset(coordinateSpace: String, onScroll: @escaping (CGFloat) -> Void) -> some View {
        self.modifier(ScrollViewOffset(coordinateSpace: coordinateSpace, onScroll: onScroll))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(contentClass: ContentClass(), speechRecognizer: SpeechRecognizer(contentClass: ContentClass()), speechSynthesizer: SpeechSynthesizer(contentClass: ContentClass()), keyboardResponder: KeyboardResponder(contentClass: ContentClass()))
    }
}
