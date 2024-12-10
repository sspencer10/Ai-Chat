import SwiftUI
import Speech
import AVFoundation
import Photos
import MediaPlayer


//class ContentClass: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
class ContentClass: NSObject, ObservableObject {
    //let speechSynthesizer = AVSpeechSynthesizer()
    
    @Published var command: String = ""
    @Published var uploadString: String = ""
    @Published var messages: [Message] = []
    @Published var isTyping: Bool = false
    @Published var selectedFile: URL?
    @Published var isDeviceListening: Bool = false
    @Published var msgProxy: ScrollViewProxy? = nil
    @AppStorage("selectedModel") var selectedModel = "gpt-4o-mini"
    @AppStorage("isSpeechEnabled") var isSpeechEnabled = true
    var userDefaultsManager = UserDefaultsManager()
    var currentSession: ChatSession?
    var musicPlayer = MPMusicPlayerController.systemMusicPlayer
    var musicPlayerIsPlaying = false
    var speechSynthesizer: SpeechSynthesizer?
    var keyboardResponder: KeyboardResponder?
    
    
    override init() {
        super.init()
        //self.speechSynthesizer = SpeechSynthesizer(contentClass: self)
        configureAudioSession()
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
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(false)
            print("Audio session successfully configured for playback.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    func isListening(x: Bool) {
        if x {
            isDeviceListening = true
        } else {
            isDeviceListening = false
        }
    }
    
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
        
        
        if command.contains("Navigate to ") {
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
            command = ""
            return
        } else if command == "Phone number is" {
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("phone number received: \(self.userDefaultsManager.phone)")
                let assistantMessage = Message(content: "What is the message?", isUser: false)
                self.messages.append(assistantMessage)
                UserDefaults.standard.set(true, forKey: "waitingForMsg")
                self.command = ""
                return
            }
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
                command = ""
                return
            } else {
                let userMessage = Message(content: command, isUser: true)
                messages.append(userMessage)
                let assistantMessage = Message(content: "<ContactsButton", isUser: false)
                messages.append(assistantMessage)
                command = ""
                return
            }
        } else if userDefaultsManager.phone != "" {
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            let msg = command
            UserDefaults.standard.set(msg, forKey: "msg")
            let number = userDefaultsManager.phone
            //let assistantMessage = Message(content: "[Send a text](shortcuts://run-shortcut?name=SendText&input=text&text={\"phone\":\"\(number)\",\"msg\":\"\(msg)\"})", isUser: false)
            let assistantMessage = Message(
                content: """
            <SendTextButton phone="\(number)" msg="\(msg)"/>
            """,
                isUser: false
            )
            messages.append(assistantMessage)
            command = ""
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
                
                
                command = ""
            return
        } else if ((command.contains("Set") || command.contains("set")) && command.contains("alarm")) {
            print("Set Alarm")
            let userMessage = Message(content: command, isUser: true)
            messages.append(userMessage)
            
            // Add the button instead of the link
            let assistantMessage = Message(
                content: """
            <SetAlarmButton time="\(command)" />
            """,
                isUser: false
            )
            messages.append(assistantMessage)
            command = ""
            return // Exit early since "Set Alarm" is handled
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
                let userMessage2 = Message(content: uploadString, isUser: true)
                messages.append(userMessage2)
                uploadString = ""
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
                                    } else if trimmedResponse.contains("SCORE:") {
                                        let lines = trimmedResponse.components(separatedBy: "\n")
                                        // Extract the second line (if it exists)
                                        if lines.count > 1 {
                                            let secondLine = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                            let cleanedString = secondLine.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                            print(cleanedString)
                                            self.speechSynthesizer?.speakResponse(response: cleanedString)
                                        }
                                    } else {
                                        self.speechSynthesizer?.speakResponse(response: trimmedResponse)
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func scrollToBottom(proxy: ScrollViewProxy?) {
        if let lastMessage = messages.last {
            if lastMessage.isUser {
                proxy?.scrollTo(lastMessage.id, anchor: .bottom)
            } else {
                proxy?.scrollTo(lastMessage.id, anchor: .top)
            }
        }
    }
    
    func scrollToBottomBottom(proxy: ScrollViewProxy?) {
        if let lastMessage = messages.last {
            proxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    func scrollToKeyboardBottom(proxy: ScrollViewProxy?) {
        proxy?.scrollTo("aboveBottomAnchor", anchor: .bottom)

    }
    
    func scrollToKeyboardBottomHide(proxy: ScrollViewProxy?) {
        proxy?.scrollTo("bottom", anchor: .bottom)

    }
    
    func scrollTop(proxy: ScrollViewProxy?) {
        if let firstMessage = messages.first {
            proxy?.scrollTo(firstMessage.id, anchor: .top)
        }
    }
    
    func loadSession(_ session: ChatSession) {
        messages = CoreDataManager.shared.fetchMessages(for: session.id!).map { message in
            Message(content: message.content ?? "", isUser: message.isUser)
        }
        currentSession = session
        scrollToBottom(proxy: msgProxy)
    }
}

