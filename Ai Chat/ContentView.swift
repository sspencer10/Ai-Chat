import SwiftUI
import AVFoundation
import Down
import UIKit
import Foundation
import CoreData
import Photos
import WebKit


struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var contentClass = ContentClass()
    @StateObject var userDefaultsManager = UserDefaultsManager()
    @State private var isShowingSettings = false
    @State private var isShowingSessions = false
    @State private var showCopiedToast = false
    @State private var isTyping = false
    @State private var isAtBottom = true
    @State var command: String = ""
    @State var webSearch: Bool = false
    @State var uploadSwitch: Bool = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
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
    
    
    
    var session: ChatSession?  // Optional session to load
    
    var body: some View {
        
        
        if ProcessInfo.processInfo.isiOSAppOnMac {
            VStack {
                contentOnMac
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(menuButton, alignment: .topTrailing)
                
            }
            //.frame(minWidth: 1000, minHeight: 700)
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(selectedModel: contentClass.$selectedModel, selectedVoice: contentClass.$selectedVoice, isSpeechEnabled: contentClass.$isSpeechEnabled)
            }
            .sheet(isPresented: $isShowingSessions) {
                ChatSessionsView { selectedSession in
                    contentClass.loadSession(selectedSession)
                }
            }
        } else {
            NavigationView {
                ZStack {
                    Color.clear
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    content
                        .navigationBarItems(trailing: menuButton)
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView(selectedModel: contentClass.$selectedModel, selectedVoice: contentClass.$selectedVoice, isSpeechEnabled: contentClass.$isSpeechEnabled)
                }
                .sheet(isPresented: $isShowingSessions) {
                    ChatSessionsView { selectedSession in
                        contentClass.loadSession(selectedSession)
                    }
                }
            }
            
            // Toast notification
            if showCopiedToast {
                VStack {
                    Spacer()
                    Text("Copied to clipboard")
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    //showCopiedToast = false
                                    UserDefaults.standard.set(false, forKey: "showCopiedToast")
                                }
                            }
                        }
                        .padding(.bottom, 50)
                }
                .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
                .onChange(of: userDefaultsManager.showCopiedToast) {
                    showCopiedToast = userDefaultsManager.showCopiedToast
                }
                .onAppear {
                    showCopiedToast = userDefaultsManager.showCopiedToast
                }
            }
            
        }
    }
    
    var menuButton: some View {
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
    }
    
    var content: some View {
        VStack {
            Text("\(contentClass.selectedModel)")
                .font(.caption)
                .foregroundColor(.gray)
                .accessibilityLabel("Selected Model: \(contentClass.selectedModel)")
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) { // Changed to LazyVStack for performance
                        ForEach(contentClass.messages) { message in
                            MessageView(message: message, contentClass: contentClass)
                        }
                    }
                    .padding()

                }
                // Scroll to the latest message when a new one is added
                .onChange(of: contentClass.messages.count) {
                    if let lastMessage = contentClass.messages.last {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 1)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    } else {
                        print("No messages available to scroll.")
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
                    .accessibilityLabel("Assistant is typing")
            }
            
            inputArea
        }
        .navigationTitle("AI Chat") // Updated to the newer modifier
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            /*
             if let session = session {
                 loadSession(session)
             }
             */
        }
        .onTapGesture {
            contentClass.hideKeyboard()
        }
    }
    
    var contentOnMac: some View {
        VStack {
            Text("\(contentClass.selectedModel)")
                .font(.caption)
                .foregroundColor(.gray)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) { // Adjusted spacing between messages
                        ForEach(contentClass.messages) { message in
                            MessageViewOnMac(message: message, contentClass: contentClass)
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
    
    
    var inputArea: some View {
        VStack {
            HStack {
                // TextField for user input
                TextField(webSearch ? "Have AI search the web..." : "Enter your question...", text: $contentClass.command)
                    .onSubmit {
                        if !contentClass.command.isEmpty {
                            contentClass.sendCommand(isUpload: userDefaultsManager.isUpload)
                            contentClass.command = ""
                        }
                    }
                    .padding(10)
                    .background(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                    .cornerRadius(12)
                    .padding(.leading, 15)
                    .offset(y: 15)
                // Conditional Button (Send or Microphone)
                Group {
                    
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
                        //.offset(x: 32) // Adjust to align properly inside the TextField
                        
                    }
                    // Microphone Button
                    Button(action: {
                        if speechRecognizer.isListening {
                            speechRecognizer.stopListening()
                        } else {
                            speechRecognizer.startListening()
                        }
                    }) {
                        Image(systemName: speechRecognizer.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 18))
                            .padding(12)
                            .foregroundColor(speechRecognizer.isListening ? .red : Color.gray.opacity(0.5))
                            .offset(x: -80) // Adjust to align properly inside the TextField
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    
                }
                .padding(.trailing, -15) // Aligns the button flush to the end
                .offset(y: 15)
            }
            
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
                        .offset(y: 6)
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
                        .offset(y: 8)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            
        }
        .onChange(of: speechRecognizer.recognizedText) {
            contentClass.command = speechRecognizer.recognizedText
        }
        .onChange(of: userDefaultsManager.webSearch) {
            webSearch = userDefaultsManager.webSearch
        }
        .onAppear {
            speechRecognizer.onCommandDetected = {
                contentClass.sendCommand(isUpload: userDefaultsManager.isUpload)
                contentClass.command = ""
            }
            webSearch = userDefaultsManager.webSearch
        }
        
        
        .frame(maxWidth: 1000)
        .padding(.vertical, 1)
        .background(Color(.systemGray6))
        .ignoresSafeArea(edges: .bottom)
        .onTapGesture {
            contentClass.hideKeyboard()
        }
    }
    
    var inputAreaOnMac: some View {
        VStack {
            HStack {
                // TextField for user input
                TextField(webSearch ? "Have AI search the web..." : "Enter your question...", text: $contentClass.command)
                    .onSubmit {
                        if !contentClass.command.isEmpty {
                            contentClass.sendCommand(isUpload: userDefaultsManager.isUpload)
                            contentClass.command = ""
                        }
                    }
                    .padding(10)
                    .background(colorScheme == .dark ? Color(.systemGray4) : Color.white)
                    .cornerRadius(12)
                    .padding(.leading, 15)
                //.padding()
                    .offset(y: 15)
                // Conditional Button (Send or Microphone)
                Group {
                    
                    // Microphone Button
                    Button(action: {
                        if speechRecognizer.isListening {
                            print("Stop")
                            speechRecognizer.stopListening()
                        } else {
                            print("Start")
                            speechRecognizer.startListening()
                        }
                    }) {
                        Image(systemName: "mic")
                            .font(.system(size: 16))
                            .padding(11)
                            .background(speechRecognizer.isListening ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .padding(.leading, 5)
                    }
                    
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
                            .padding(.horizontal, 35)
                        
                    }
                    
                    
                }
                .padding(.trailing, -15) // Aligns the button flush to the end
                .offset(y: 15)
            }
            
            // Second Row
            HStack {
                // Upload Button
                Button(action: {
                    showFilePicker = true
                })
                {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .padding(10)
                        .background(showFilePicker || userDefaultsManager.isUpload ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .offset(y: 15)
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
                        .font(.system(size: 16))
                        .padding(10)
                        .background(webSearch ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .offset(y: 15)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .onChange(of: speechRecognizer.recognizedText) {
            contentClass.command = speechRecognizer.recognizedText
        }
        .onChange(of: userDefaultsManager.webSearch) {
            webSearch = userDefaultsManager.webSearch
        }
        .onAppear {
            speechRecognizer.onCommandDetected = {
                contentClass.sendCommand(isUpload: userDefaultsManager.isUpload)
                contentClass.command = ""
            }
            webSearch = userDefaultsManager.webSearch
        }
        .onTapGesture {
            contentClass.hideKeyboard()
        }
        
        //.frame(maxWidth: 1000)
        .padding(.vertical, 1)
        //.ignoresSafeArea(edges: .bottom)
        .padding(.bottom, 30)
        .background(Color(.systemGray5))
        
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





// Typing indicator view for assistant typing animation
struct TypingIndicatorView: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(animate ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animate)
            
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(animate ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: animate)
            
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(animate ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4), value: animate)
        }
        .onAppear {
            animate = true
        }
        .padding(.bottom, 10)
    }
}

struct AssistantImageView: View {
    let imageUrlString: String
    @ObservedObject var contentClass: ContentClass
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    @State private var loadFailed = false
    
    var body: some View {
        VStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .frame(width: 200, height: 200)
                    .contextMenu {
                        Button(action: {
                            contentClass.saveImageToPhotos(image: image)
                        }) {
                            Label("Save Image", systemImage: "square.and.arrow.down")
                        }
                    }
                    .padding()
            } else if isLoading {
                ProgressView()
                    .frame(width: 200, height: 200)
            } else if loadFailed {
                Text("Failed to load image")
                    .frame(width: 200, height: 200)
            } else {
                // Placeholder before the image starts loading
                Color.gray.opacity(0.2)
                    .frame(width: 200, height: 200)
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    func loadImage() {
        guard let url = URL(string: imageUrlString) else {
            loadFailed = true
            return
        }
        
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let uiImage = UIImage(data: data) {
                    loadedImage = uiImage
                } else {
                    loadFailed = true
                }
            }
        }.resume()
    }
}

struct AssistantImageViewOnMac: View {
    let imageUrlString: String
    @ObservedObject var contentClass: ContentClass
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    @State private var loadFailed = false
    
    var body: some View {
        VStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .frame(width: 200, height: 200)
                    .onLongPressGesture {
                        contentClass.saveImageToPhotos(image: image)
                    }
                    .padding()
            } else if isLoading {
                ProgressView()
                    .frame(width: 200, height: 200)
            } else if loadFailed {
                Text("Failed to load image")
                    .frame(width: 200, height: 200)
            } else {
                // Placeholder before the image starts loading
                Color.gray.opacity(0.2)
                    .frame(width: 200, height: 200)
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    func loadImage() {
        guard let url = URL(string: imageUrlString) else {
            loadFailed = true
            return
        }
        
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let uiImage = UIImage(data: data) {
                    loadedImage = uiImage
                } else {
                    loadFailed = true
                }
            }
        }.resume()
    }
}

struct MessageView: View {
    let message: Message
    @ObservedObject var contentClass: ContentClass
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
                    .onLongPressGesture(minimumDuration: 1.0) {
                        UIPasteboard.general.string = message.content
                        contentClass.triggerToast()
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            contentClass.triggerToast()
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
            } else {
                if message.content.contains("oaidalleapiprodscus") {
                    // Handle image messages
                    AssistantImageView(imageUrlString: message.content, contentClass: contentClass)
                } else {
                    /*
                    // Handle text messages using WebView
                    WebView(
                        htmlContent: generateHTML(from: message.content),
                        onLoadFinished: {
                            print("WebView successfully loaded content for message ID: \(message.id)")
                        },
                        onLoadError: { error in
                            print("WebView failed to load content for message ID: \(message.id). Error: \(String(describing: error?.localizedDescription))")
                        }
                    )
                     */
                    FormattedTextView(message: message.content)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .frame(maxWidth: 760, alignment: .leading)
                    .onLongPressGesture(minimumDuration: 1.0) {
                        UIPasteboard.general.string = message.content
                        contentClass.triggerToast()
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            contentClass.triggerToast()
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }                }
                Spacer()
            }
        }
        .id(message.id)
    }
    
    // Function to Convert Markdown to HTML with Custom CSS
    func generateHTML(from markdown: String) -> String {
        do {
            let down = Down(markdownString: markdown)
            let html = try down.toHTML()
            let styledHTML = """
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
               <style>
                   body {
                       font-family: -apple-system, Helvetica, Arial, sans-serif;
                       padding: 16px;
                       background-color: white; /* Ensures visibility */
                       color: #000;
                   }
                   pre {
                       background-color: #000; /* Black background for code blocks */
                       padding: 12px;
                       border-radius: 8px; /* Rounded corners */
                       overflow-x: auto;
                       margin: 8px 0; /* Spacing around code blocks */
                   }
                   code {
                       color: #00FF00; /* Green text for code */
                       font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
                       font-size: 14px;
                       white-space: pre-wrap; /* Ensure proper text wrapping */
                   }
                   /* Preserve list bullets */
                   ul {
                       list-style-type: disc;
                       margin-left: 20px;
                   }
                   a {
                       color: blue;
                       text-decoration: none;
                   }
               </style>
            </head>
            <body>
                \(html)
            </body>
            </html>
            """
            return styledHTML
        } catch {
            print("Failed to convert Markdown to HTML: \(error)")
            return "<p>Error rendering Markdown.</p>"
        }
    }
}
struct MessageViewOnMac: View {
    let message: Message
    @ObservedObject var contentClass: ContentClass
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .frame(maxWidth: 760, alignment: .trailing)
                    .onLongPressGesture(minimumDuration: 1.0) {
                        UIPasteboard.general.string = message.content
                        contentClass.triggerToast()
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            contentClass.triggerToast()
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
            } else {
                if message.content.contains("oaidalleapiprodscus") {
                    // Handle image messages
                    AssistantImageViewOnMac(imageUrlString: message.content, contentClass: contentClass)
                } else {
                    // Handle text messages
                    FormattedTextView(message: message.content)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: 760, alignment: .leading)
                        .onLongPressGesture(minimumDuration: 1.0) {
                            UIPasteboard.general.string = message.content
                            contentClass.triggerToast()
                        }
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = message.content
                                contentClass.triggerToast()
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                }
                Spacer()
            }
        }
        .id(message.id)
    }
}



class ContentClass: ObservableObject {
    @Published var command: String = ""
    @Published var uploadString: String = ""
    @Published var messages: [Message] = []
    @Published var isTyping: Bool = false
    @Published var selectedFile: URL?
    @AppStorage("selectedModel") var selectedModel = "gpt-4o-mini"
    @AppStorage("selectedVoice") var selectedVoice = "com.apple.ttsbundle.siri_male_en-US_compact"
    @AppStorage("isSpeechEnabled") var isSpeechEnabled = true
    
    
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    var currentSession: ChatSession?
    
    // Function to format the session title with date and time
    private func generateSessionTitle() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return "Session from \(dateFormatter.string(from: Date()))"
    }
    
    // Start a new chat session
    func startNewSession() {
        guard currentSession != nil else { return }
        // Clear the current session
        currentSession = nil
        messages.removeAll()
        isTyping = false
    }
    
    // Function to start a new session only if one doesn’t exist
    private func startNewSessionIfNeeded(title: String) {
        if currentSession == nil {
            currentSession = CoreDataManager.shared.createSession(title: title)
            //messages.removeAll()
        }
    }
    
    func sendCommand(isUpload: Bool) {
        guard !command.isEmpty else { return }
        
        if command.contains("Set alarm") {
            print("Set Alarm")
            let pattern = "\\b\\d{1,2}:\\d{2}\\b"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let nsString = command as NSString
                let results = regex.matches(in: command, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first {
                    let time = nsString.substring(with: match.range) // Extract the matched time as a string
                    let urlString = "shortcuts://run-shortcut?name=Add%20Alarm&input=text&text=\(time)"
                    print("urlString \(urlString)")
                    let userMessage = Message(content: command, isUser: true)
                    messages.append(userMessage)
                    let assistantMessage = Message(content: "[Tap to confirm setting alarm for \(time)](shortcuts://run-shortcut?name=Add%20Alarm&input=text&text=\(time))", isUser: false)
                    messages.append(assistantMessage)
                    command = ""
                    return // Exit early since "Set Alarm" is handled
                }
            } catch {
                print("Error creating regular expression: \(error)")
            }
        } else {
            var fullCommand = command // Full command sent to the server
            
            if isUpload {
                fullCommand = "Upload: /home/steve/ai/uploaded.json : \(command)"
                if let savedData = UserDefaults.standard.data(forKey: "savedJSON") {
                    if let jsonString = String(data: savedData, encoding: .utf8) {
                        print("Retrieved JSON as String: \(jsonString)")
                        uploadString = jsonString
                    } else {
                        print("Failed to convert JSON data to String.")
                    }
                } else {
                    print("No JSON data found in UserDefaults.")
                }
                UserDefaults.standard.set(false, forKey: "isUpload")
            }
            
            print("Full Command: \(fullCommand)")
            
            // Add the user's message (without the "Upload" prefix) to the chat history
            let userMessage = Message(content: command, isUser: true) // Only the raw command is shown
            messages.append(userMessage)
            
            // Prepare the chat history to send to the server (limit to last 20 entries)
            var recentHistory = Array(messages.suffix(20)).map {
                ["role": $0.isUser ? "user" : "assistant", "content": $0.content]
            }
            
            // Add jsonString to recentHistory without showing it in messages
            if !uploadString.isEmpty {
                recentHistory.append(["role": "user", "content": uploadString])
            }
            
            // Debug output to verify recentHistory
            print("recentHistory with jsonString: \(recentHistory)")
            
            // Prepare and send API request
            let urlString = "https://ai.sspencer10.com/ask"
            guard let url = URL(string: urlString) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            // Add your API key here
            let apiKey = "21d846e46126a371ca742ac9705de31130bf196c"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            // Prepare the parameters to include the full command, model, and chat history
            let parameters: [String: Any] = [
                "command": fullCommand, // Use the full command here
                "model": selectedModel,
                "history": recentHistory,
                "webSearch": UserDefaultsManager().webSearch
            ]
            
            command = ""  // Clear the command text after sending
            isTyping = true
            
            // Convert parameters to JSON data
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("Error 001: \(error?.localizedDescription ?? "Unknown error")")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.command = ""  // Clear the command in case of error
                        UserDefaults.standard.set(false, forKey: "webSearch")
                    }
                    return
                }
                
                // Variables to hold the trimmed response and extracted title
                var trimmedResponse = ""
                var extractedTitle = ""
                
                // Parse the JSON response from the API
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        
                        // Check for an error in the response
                        if let errorMessage = jsonResponse["error"] as? String {
                            DispatchQueue.main.async {
                                UserDefaults.standard.set(false, forKey: "webSearch")
                                let assistantMessage = Message(content: "Error 002: \(errorMessage)", isUser: false)
                                self.messages.append(assistantMessage)
                                self.isTyping = false
                                self.command = ""
                            }
                            return
                        }
                        
                        // Proceed with handling a successful response
                        if let responseText = jsonResponse["response"] as? String {
                            let cost = jsonResponse["total_cost"] as? String ?? "N/A"
                            let modelUsed = jsonResponse["model_used"] as? String ?? "Unknown model"
                            print("Raw Response: \(responseText)")
                            // Check if the response contains "**Title:**"
                            if let titleRange = responseText.range(of: "**Title:**") {
                                // Extract the main content before the title
                                trimmedResponse = String(responseText[..<titleRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // Extract the content after "**Title:**"
                                extractedTitle = String(responseText[titleRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                                // Start a new session if one does not exist
                                self.startNewSessionIfNeeded(title: extractedTitle)
                                CoreDataManager.shared.addMessage(userMessage.content, isUser: userMessage.isUser, to: self.currentSession!)
                                print("Title: \(extractedTitle)")
                            } else {
                                // If no title is found, use the full response text
                                trimmedResponse = responseText
                                self.startNewSessionIfNeeded(title: self.generateSessionTitle())
                                CoreDataManager.shared.addMessage(userMessage.content, isUser: userMessage.isUser, to: self.currentSession!)
                            }
                            
                            DispatchQueue.main.async {
                                // Append the trimmed response to the messages
                                let assistantMessage = Message(content: trimmedResponse, isUser: false)
                                self.messages.append(assistantMessage)
                                self.isTyping = false
                                
                                // Save to Core Data
                                CoreDataManager.shared.addMessage(assistantMessage.content, isUser: assistantMessage.isUser, to: self.currentSession!)
                                
                                print("Model Used: \(modelUsed)")
                                print("Cost: \(cost)")
                                UserDefaults.standard.set(cost, forKey: "cost")
                                
                                // Store the extracted title if it exists
                                if !extractedTitle.isEmpty {
                                    print("Extracted Title: \(extractedTitle)")
                                    UserDefaults.standard.set(extractedTitle, forKey: "lastTitle")
                                }
                                
                                // Update the total cost
                                let subtotal = UserDefaults.standard.string(forKey: "totalSpent") ?? "0.00"
                                if let doubleSubTotal = Double(subtotal), let doubleCost = Double(cost) {
                                    let total = doubleSubTotal + doubleCost
                                    UserDefaults.standard.set(total, forKey: "totalSpent")
                                }
                                
                                // Speak the response if speech is enabled
                                if self.isSpeechEnabled {
                                    if trimmedResponse.contains("oaidalleapiprodscus") {
                                        print("won't speak this response")
                                    } else {
                                        self.speakResponse(response: trimmedResponse)
                                    }
                                }
                                UserDefaults.standard.set(false, forKey: "webSearch")
                            }
                        }
                    }
                } catch {
                    UserDefaults.standard.set(false, forKey: "webSearch")
                    print("Error parsing JSON: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.command = ""
                        let assistantMessage = Message(content: "Sorry, there was an error processing your request.", isUser: false)
                        self.messages.append(assistantMessage)
                        self.isTyping = false
                    }
                }            }
            task.resume()
        }
    }
    
    func saveImageToPhotos(image: UIImage) {
        checkPhotoLibraryPermission { authorized in
            if authorized {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                print("Image saved to photos")
                // Optionally show user feedback here
            } else {
                print("Permission to save photos was denied.")
            }
        }
    }
    
    func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                completion(newStatus == .authorized)
            }
        default:
            completion(false)
        }
    }
    
    
    // Function to speak the first paragraph of the response using the selected voice
    func speakResponse(response: String) {
        // Extract the first paragraph before the first newline character
        let firstParagraph = response.components(separatedBy: "\n").first ?? response
        
        let utterance = AVSpeechUtterance(string: firstParagraph)
        utterance.volume = 1.0
        
        // Use the selected voice if available, otherwise default to English (US)
        if let voice = AVSpeechSynthesisVoice(identifier: selectedVoice) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        // Speak the extracted first paragraph
        speechSynthesizer.speak(utterance)
    }
    
    func copyToClipboard(_ text: String) {
#if targetEnvironment(macCatalyst) || os(iOS)
        UIPasteboard.general.string = text
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
    
    
    func triggerToast() {
        withAnimation {
            UserDefaults.standard.set(true, forKey: "showCopiedToast")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                UserDefaults.standard.set(false, forKey: "showCopiedToast")
            }
        }
    }
    
    func hideKeyboard() {
        print("hide Keyboard")
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func loadSession(_ session: ChatSession) {
        messages = CoreDataManager.shared.fetchMessages(for: session.id!).map { message in
            Message(content: message.content ?? "", isUser: message.isUser)
        }
        currentSession = session
    }
}

import Speech
import SwiftUI
import AVFoundation

class SpeechRecognizer: ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = "" {
        didSet {
            onRecognizedTextUpdate?(recognizedText) // Notify external state of text updates
        }
    }
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    
    var onCommandDetected: (() -> Void)?
    var onRecognizedTextUpdate: ((String) -> Void)? // Closure for updating external state
    
    func startListening() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startRecognition()
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition authorization denied or unavailable.")
                @unknown default:
                    print("Unknown authorization status.")
                }
            }
        }
    }
    
    private func startRecognition() {
        if audioEngine.isRunning {
            stopListening()
        }
        print("start listening")
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
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        silenceTimer?.invalidate()
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
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

import SwiftUI
import WebKit

struct TestWebView: View {
    var body: some View {
        WebView(
            htmlContent: """
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        font-family: -apple-system, Helvetica, Arial, sans-serif;
                        padding: 16px;
                        background-color: white;
                        color: #000;
                    }
                    pre {
                        background-color: #000;
                        padding: 12px;
                        border-radius: 8px;
                        overflow-x: auto;
                        margin: 8px 0;
                    }
                    code {
                        color: #00FF00;
                        font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
                        font-size: 14px;
                    }
                    ul {
                        list-style-type: disc;
                        margin-left: 20px;
                    }
                    a {
                        color: blue;
                        text-decoration: none;
                    }
                </style>
            </head>
            <body>
                <p>Hello! How can I assist you today?</p>
                <pre><code>func greet() {
                    print("Hello, World!")
                }
                </code></pre>
                <ul>
                    <li>Item 1</li>
                    <li>Item 2</li>
                </ul>
                <a href="https://www.openai.com">Visit OpenAI</a>
            </body>
            </html>
            """,
            onLoadFinished: {
                print("TestWebView successfully loaded content.")
            },
            onLoadError: { error in
                print("TestWebView failed to load content: \(String(describing: error?.localizedDescription))")
            }
        )
        .frame(width: 300, height: 400) // Fixed size for testing
        .background(Color.gray.opacity(0.2)) // Light gray background for visibility
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red, lineWidth: 2) // Red border for visibility
        )
    }
}

struct TestWebView_Previews: PreviewProvider {
    static var previews: some View {
        TestWebView()
    }
}
