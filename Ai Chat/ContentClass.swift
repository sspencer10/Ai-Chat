import SwiftUI
import Speech
import AVFoundation
import Photos
import MediaPlayer

class ContentClass: NSObject, ObservableObject, URLSessionDataDelegate {
    @Published var uploadString: String = ""
    @Published var isTyping: Bool = false
    @Published var selectedFile: URL?
    @Published var showAlert: Bool = false
    @Published var isDeviceListening: Bool = false
    @Published var msgProxy: ScrollViewProxy? = nil
    @Published var lineCount: Int = 1
    @Published var messages: [Message] = []
    
    // Track partial streaming text
    private var partialResponseBuffer: String = ""
    
    // We’ll keep a reference to the streaming task and session so we can cancel if needed
    private var streamingTask: URLSessionDataTask?
    private var streamingSession: URLSession?
    
    // Example property to store your server’s Bearer token
    let apiKey = "21d846e46126a371ca742ac9705de31130bf196c"
    
    @AppStorage("selectedModel") var selectedModel = "gpt-4o-mini"
    @AppStorage("isSpeechEnabled") var isSpeechEnabled = true
    var userDefaultsManager = UserDefaultsManager()
    var currentSession: ChatSession?
    var musicPlayer = MPMusicPlayerController.systemMusicPlayer
    var musicPlayerIsPlaying = false
    var speechSynthesizer: SpeechSynthesizer?
    
    // --- CHANGED: We'll track whether or not a response is streaming.
    private var isResponseStreaming: Bool = false
    // --- CHANGED: We'll buffer data for non-streaming usage.
    private var nonStreamingDataBuffer = Data()
    
    // ----------------------------------------------------------------
    // ADDED: Throttle tracking
    private var lastUIUpdateTime = Date(timeIntervalSince1970: 0) // Holds the last time we updated the UI
    private let uiUpdateThrottleInterval: TimeInterval = 0.3      // Only update the UI every 0.2s
    
    // ADDED: We'll store partial messages to save to Core Data after streaming completes
    private var batchedCoreDataMessages: [(text: String, isUser: Bool)] = []    // ----------------------------------------------------------------
    
    
    override init() {
        super.init()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("ContentClass deinitialized")
    }
    
    func proxySetter(_ proxy: ScrollViewProxy) {
        self.msgProxy = proxy
    }
    
    func setSpeechSynthesizer(_ synthesizer: SpeechSynthesizer) {
        self.speechSynthesizer = synthesizer
    }
    
    func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try audioSession.setActive(false)
            print("Audio session successfully configured for playback.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
 
    
    func isListening(x: Bool) {
        isDeviceListening = x
    }
    
    func setShowAlert(_ x: Bool) {
        showAlert = x
    }
    
    private func generateSessionTitle() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return "Session from \(dateFormatter.string(from: Date()))"
    }
    
    func startNewSession() {
        guard currentSession != nil else { return }
        currentSession = nil
        messages.removeAll()
        isTyping = false
    }
    
    private func startNewSessionIfNeeded(title: String) {
        if currentSession == nil {
            currentSession = CoreDataManager.shared.createSession(title: title)
        }
    }
    
    
    // --------------------------------------------------------
    // CHANGED: sendCommand with integrated SSE logic + throttling + batching
    // --------------------------------------------------------
    func sendCommand(isUpload: Bool, command: String) {
        
        guard !command.isEmpty else {
            print("Empty command")
            return
        }
        
        // 1) Check custom logic: Navigate, phone text, alarm, etc...
        if command.contains("Navigate to ") || command.contains("directions to ") {
            print("Navigation")
            var address = command.replacingOccurrences(of: "Navigate to ", with: "")
            address = address.replacingOccurrences(of: " ", with: "+")
            
            print("address \(address)")
            UserDefaults.standard.set(address, forKey: "address")
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            let assistantMessage = Message(
                content: """
                <NavigationButton address="\(address)"/>
                """,
                isUser: false
            )
            messages.append(assistantMessage)
            startNewSessionIfNeeded(title: "Get Directions")

            return
            
        } else if command == "Phone number is" {
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                print("phone number received: \(self.userDefaultsManager.phone)")
                let assistantMessage = Message(content: "What is the message?", isUser: false)
                self.messages.append(assistantMessage)
                UserDefaults.standard.set(true, forKey: "waitingForMsg")
  
            }
            return
            
        } else if command.contains("Send a text") {
            print("Send a text")
            if let match = command.range(of: "\\d{10}", options: .regularExpression) {
                let number = String(command[match])
                print("Extracted number: \(number)")
                let userMessage = Message(content: command, isUser: true)
                messages.append(userMessage)
                let assistantMessage = Message(content: "What is the message?", isUser: false)
                messages.append(assistantMessage)
                UserDefaults.standard.set(number, forKey: "phone")
                startNewSessionIfNeeded(title: "Send a Text")
                return
            } else {
                let userMessage = Message(content: command, isUser: true)
                messages.append(userMessage)
                let assistantMessage = Message(content: "<ContactsButton", isUser: false)
                messages.append(assistantMessage)
                startNewSessionIfNeeded(title: "Send a Text")
                return
            }
            
        } else if userDefaultsManager.phone != "" {
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            let msg = command
            UserDefaults.standard.set(msg, forKey: "msg")
            let number = userDefaultsManager.phone
            let assistantMessage = Message(
                content: """
                <SendTextButton phone="\(number)" msg="\(msg)"/>
                """,
                isUser: false
            )
            messages.append(assistantMessage)

            return
            
        } else if userDefaultsManager.waitingForMsg {
            UserDefaults.standard.set(false, forKey: "waitingForMsg")
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            let msg = command
            UserDefaults.standard.set(msg, forKey: "msg")
            let number = userDefaultsManager.phoneNumber
            let assistantMessage = Message(
                content: """
                <SendTextButton phone="\(number)" msg="\(msg)"/>
                """,
                isUser: false
            )
            messages.append(assistantMessage)
            

            return
            
        } else if ((command.contains("Set") || command.contains("set")) && command.contains("alarm")) {
            print("Set Alarm")
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            let assistantMessage = Message(
                content: """
                <SetAlarmButton time="\(command)" />
                """,
                isUser: false
            )
            messages.append(assistantMessage)
            startNewSessionIfNeeded(title: "Set an Alarm")

            return
            
        } else {
            // 2) If not one of those special commands, proceed to SSE logic
            var fullCommand = command
            
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
            
            // Add the user's message
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            
            // Build recent history
            var recentHistory = Array(messages.suffix(20)).map {
                ["role": $0.isUser ? "user" : "assistant", "content": $0.content]
            }
            
            if !uploadString.isEmpty {
                recentHistory.append(["role": "user", "content": uploadString])
                let userMessage2 = Message(content: uploadString, isUser: true)
                messages.append(userMessage2)
                uploadString = ""
            }
            
            // Prepare request
            let urlString = "https://ai.sspencer10.com/ask"
            guard let url = URL(string: urlString) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // Accept SSE
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            
            let parameters: [String: Any] = [
                "command": fullCommand,
                "model": selectedModel,
                "history": recentHistory,
                "webSearch": userDefaultsManager.webSearch
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])
            
            self.isTyping = true
            // Clear any old buffers
            self.isResponseStreaming = false
            self.nonStreamingDataBuffer.removeAll()
            self.partialResponseBuffer = ""
            
            // ADDED: Clear out our batch list for Core Data
            self.batchedCoreDataMessages.removeAll() // ADDED
            
            // Create a custom session
            let config = URLSessionConfiguration.default
            self.streamingSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            
            // Start the SSE data task
            self.streamingTask = streamingSession?.dataTask(with: request)
            self.streamingTask?.resume()
            
        }
        //command = ""
        //hideKeyboard()
    }
    // --------------------------------------------------------

    
    private func finishStreamWithText(_ finalText: String) {
        
        var trimmedResponse = finalText
        var extractedTitle = ""
        
        if let titleRange = finalText.range(of: "**Title:**") {
            trimmedResponse = String(finalText[..<titleRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            extractedTitle = String(finalText[titleRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            startNewSessionIfNeeded(title: extractedTitle)
            
            // CHANGED: Instead of adding to Core Data for every partial, we do it once here
            if let lastUserMessage = self.messages.last(where: { $0.isUser }) {
                // We'll just queue it up. (Alternatively, you can call addMessage here.)
                batchedCoreDataMessages.append((lastUserMessage.content, true)) // ADDED
            }
            print("Title: \(extractedTitle)")
            
        } else {
            startNewSessionIfNeeded(title: self.generateSessionTitle())
            if let lastUserMessage = self.messages.last(where: { $0.isUser }) {
                batchedCoreDataMessages.append((lastUserMessage.content, true)) // ADDED
            }
        }
        
        // 3) Update or append the assistant message in the UI
        if let lastIndex = self.messages.lastIndex(where: { !$0.isUser }) {
            var lastAssist = self.messages[lastIndex]
            lastAssist.content = trimmedResponse
            self.messages[lastIndex] = lastAssist
            // ADDED: also queue the assistant message
            batchedCoreDataMessages.append((trimmedResponse, false))
        } else {
            let assistantMessage = Message(content: trimmedResponse, isUser: false)
            self.messages.append(assistantMessage)
            // ADDED
            batchedCoreDataMessages.append((trimmedResponse, false))
        }
        
        // Once the entire streaming is done, we do a single batch save
        if let session = self.currentSession {
            // Suppose you have an array called `batchedCoreDataMessages`,
            // each element is `(String, Bool)` for (text, isUser).
            CoreDataManager.shared.batchAddMessages(batchedCoreDataMessages, to: session)
        }
        isTyping = false
        // 5) Speak if needed
        if self.isSpeechEnabled {
            if trimmedResponse.contains("oaidalleapiprodscus") {
                print("won't speak this response")
            } else if trimmedResponse.contains("SCORE:") {
                let lines = trimmedResponse.components(separatedBy: "\n")
                if lines.count > 1 {
                    let secondLine = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanedString = secondLine
                        .replacingOccurrences(of: "**", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    print(cleanedString)
                    self.speechSynthesizer?.speakResponse(response: cleanedString)
                }
            } else {
                self.speechSynthesizer?.speakResponse(response: trimmedResponse)
            }
            return
        } else {
            return
        }
    }
    
    func saveImageToPhotos(image: UIImage) {
        checkPhotoLibraryPermission { authorized in
            if authorized {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                print("Image saved to photos")
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
    
    func stopSpeechIfNeeded() {
        print("Stopping speech from ContentClass...")
        speechSynthesizer?.stopSpeech()
    }
    
    func hideKeyboard() {
        print("hide Keyboard")
        //UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func loadSession(_ session: ChatSession) {
        messages = CoreDataManager.shared.fetchMessages(for: session.id!).map { message in
            Message(content: message.content ?? "", isUser: message.isUser)
        }
        currentSession = session
    }
}


// MARK: - URLSessionDataDelegate
extension ContentClass {
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        defer { completionHandler(.allow) }
        
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        let contentType = httpResponse.allHeaderFields["Content-Type"] as? String ?? ""
        print("Received contentType: \(contentType)")
        
        if contentType.contains("text/event-stream") {
            self.isResponseStreaming = true
            // We add a placeholder so that user sees something
            let assistantPlaceholder = Message(content: "", isUser: false)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messages.append(assistantPlaceholder)
            }
        } else {
            self.isResponseStreaming = false
            let assistantPlaceholder = Message(content: "Generating response...", isUser: false)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messages.append(assistantPlaceholder)
            }
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        
        if isResponseStreaming {
            guard let chunkString = String(data: data, encoding: .utf8),
                  !chunkString.isEmpty else { return }
            
            let lines = chunkString.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("data:") else { continue }
                
                if trimmed == "data: [DONE]" {
                    let finalText = self.partialResponseBuffer
                    self.partialResponseBuffer = ""
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.finishStreamWithText(finalText)
                    }
                    return
                }
                
                let jsonString = trimmed.replacingOccurrences(of: "data: ", with: "")
                guard let jsonData = jsonString.data(using: .utf8),
                      let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let partialContent = jsonObject["content"] as? String else {
                    continue
                }
                
                self.partialResponseBuffer += partialContent
                
                // ADDED: Throttle partial UI updates
                let now = Date()
                if now.timeIntervalSince(lastUIUpdateTime) > uiUpdateThrottleInterval {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if let lastMessageIndex = self.messages.lastIndex(where: { !$0.isUser }) {
                            var updatedMsg = self.messages[lastMessageIndex]
                            updatedMsg.content = self.partialResponseBuffer
                            self.messages[lastMessageIndex] = updatedMsg
                        } else {
                            let partialMsg = Message(content: self.partialResponseBuffer, isUser: false)
                            self.messages.append(partialMsg)
                        }
                    }
                    lastUIUpdateTime = now
                }
            }
            
        } else {
            // Non-streaming
            self.nonStreamingDataBuffer.append(data)
        }
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isTyping = false
        }
        
        if let error = error {
            print("Stream error: \(error)")
            return
        }
        
        // If it's non-streaming, parse JSON
        if !isResponseStreaming {
            let finalData = self.nonStreamingDataBuffer
            self.nonStreamingDataBuffer.removeAll()
            
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: finalData, options: []) as? [String: Any],
                   let finalText = jsonObject["response"] as? String {
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.finishStreamWithText(finalText)
                    }
                } else {
                    print("Could not parse JSON or missing 'response' key.")
                }
            } catch {
                print("JSON parse error: \(error)")
            }
        } else {
            print("Streaming completed successfully.")
        }
    }
}
