import Foundation
import SwiftUI
import CoreData
import AVFoundation

class ContentClass: ObservableObject {
    @Published var command: String = ""
    @Published var messages: [Message] = []
    @Published var isTyping: Bool = false
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
        guard let session = currentSession else { return }
        
        // Clear the current session
        currentSession = nil
        messages.removeAll()  // Clear messages as well
        isTyping = false
    }
    
    // Function to start a new session only if one doesn’t exist
    private func startNewSessionIfNeeded(title: String) {
        if currentSession == nil {
            currentSession = CoreDataManager.shared.createSession(title: title)
            //messages.removeAll()
        }
    }
    
    func sendCommand() {
        guard !command.isEmpty else { return }
        
        // Add the user's message to the chat history
        let userMessage = Message(content: command, isUser: true)
        messages.append(userMessage)
        
        // Save the message to Core Data
        
        // Prepare the chat history to send to the server (limit to last 20 entries)
        let recentHistory = Array(messages.suffix(20)).map {
            ["role": $0.isUser ? "user" : "assistant", "content": $0.content]
        }
        print("recentHistory \(recentHistory)")
        
        // Prepare and send API request
        let urlString = "https://ai.sspencer10.com/ask"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add your API key here
        let apiKey = "21d846e46126a371ca742ac9705de31130bf196c"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Prepare the parameters to include the command, model, and chat history
        let parameters: [String: Any] = [
            "command": command,
            "model": selectedModel,
            "history": recentHistory
        ]
        
        command = ""  // Clear the command text after sending
        isTyping = true
        
        // Convert parameters to JSON data
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.command = ""  // Clear the command in case of error
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
                            let assistantMessage = Message(content: "Error: \(errorMessage)", isUser: false)
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
                                self.speakResponse(response: trimmedResponse)
                            }
                        }
                    }
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.command = ""
                    let assistantMessage = Message(content: "Sorry, there was an error processing your request.", isUser: false)
                    self.messages.append(assistantMessage)
                    self.isTyping = false
                }
            }
        }
        task.resume()
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

struct FormattedTextView: View {
    let message: String
    
    var body: some View {
        let lines = preprocessMessage(message)
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {
                case .heading(let text, let level):
                    if level == 1 {
                        Text(text).font(.title).bold().padding(.vertical, 8)
                    } else if level == 2 {
                        Text(text).font(.title2).bold().padding(.vertical, 6)
                    } else if level == 3 {
                        Text(text).font(.title3).bold().padding(.vertical, 4)
                    } else {
                        Text(text).font(.body).bold()
                    }
                case .listItem(let text):
                    HStack(alignment: .top) {
                        Text("• ")
                        Text.formattedText(from: text)
                    }
                    .padding(.leading, 10)
                case .codeBlock(let code):
                    CodeBlockView(text: code)
                case .paragraph(let text):
                    Text.formattedText(from: text)
                case .text(let content):
                    Text(content)
                case .inlineCode(let code):
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                case .link(let text, let url):
                    Link(text, destination: URL(string: url)!)
                default:
                    EmptyView()
                }
                
            }
        }

    }
}

struct CodeBlockView: View {
    let text: String
    @StateObject var contentClass = ContentClass()
    
    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.green)
            .padding()
            .background(Color.black)
            .cornerRadius(8)
            .onLongPressGesture(minimumDuration: 1.0) {
                UIPasteboard.general.string = text
                contentClass.triggerToast()
            }
            .contextMenu {
                Button(action: {
                    UIPasteboard.general.string = text
                    contentClass.triggerToast()
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
    }
}

extension Text {
    static func formattedText(from message: String) -> Text {
        _ = #"(\*\*)(.*?)\1"#
        _ = #"(_)(.*?)\1"#
        _ = #"(`)(.*?)\1"#
        
        var formattedText = Text("")
        var currentIndex = message.startIndex

        let combinedPattern = #"(\*\*.*?\*\*)|(_.*?_)|(`.*?`)"#
        let regex = try? NSRegularExpression(pattern: combinedPattern, options: [])
        let matches = regex?.matches(in: message, range: NSRange(location: 0, length: message.utf16.count))
        
        matches?.forEach { match in
            guard let range = Range(match.range, in: message) else { return }
            
            if currentIndex < range.lowerBound {
                let plainText = String(message[currentIndex..<range.lowerBound])
                formattedText = formattedText + Text(plainText)
            }
            
            let matchedText = String(message[range])
            
            if matchedText.hasPrefix("**"), matchedText.hasSuffix("**") {
                let boldText = matchedText.replacingOccurrences(of: "**", with: "")
                formattedText = formattedText + Text(boldText).bold()
            } else if matchedText.hasPrefix("_"), matchedText.hasSuffix("_") {
                let italicText = matchedText.replacingOccurrences(of: "_", with: "")
                formattedText = formattedText + Text(italicText).italic()
            } else if matchedText.hasPrefix("`"), matchedText.hasSuffix("`") {
                let codeText = matchedText.replacingOccurrences(of: "`", with: "")
                formattedText = formattedText + Text(codeText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
            }
            
            currentIndex = range.upperBound
        }
        
        if currentIndex < message.endIndex {
            let remainingText = String(message[currentIndex..<message.endIndex])
            formattedText = formattedText + Text(remainingText)
        }
        
        return formattedText
    }
}

enum FormattedText {
    case text(String)
    case inlineCode(String)
    case heading(String, Int)
    case listItem(String)
    case codeBlock(String)
    case paragraph(String)
    case link(text: String, url: String)
}

enum MarkdownLine {
    case text(String)
    case inlineCode(String)
    case heading(String, Int)
    case listItem(String)
    case codeBlock(String)
    case paragraph(String)
    case link(text: String, url: String)
}

func preprocessMessage(_ message: String) -> [MarkdownLine] {
    let lines = message.components(separatedBy: "\n")
    var result: [MarkdownLine] = []
    var inCodeBlock = false
    var codeBlockText = ""

    for line in lines {
        if line.hasPrefix("```") {
            inCodeBlock.toggle()
            if !inCodeBlock {
                result.append(.codeBlock(codeBlockText))
                codeBlockText = ""
            }
        } else if inCodeBlock {
            codeBlockText += line + "\n"
        } else if line.hasPrefix("#### ") {
            let headingText = line.replacingOccurrences(of: "#### ", with: "")
            result.append(.heading(headingText, 4))
        } else if line.hasPrefix("### ") {
            let headingText = line.replacingOccurrences(of: "### ", with: "")
            result.append(.heading(headingText, 3))
        } else if line.hasPrefix("## ") {
            let headingText = line.replacingOccurrences(of: "## ", with: "")
            result.append(.heading(headingText, 2))
        } else if line.hasPrefix("# ") {
            let headingText = line.replacingOccurrences(of: "# ", with: "")
            result.append(.heading(headingText, 1))
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            let listItemText = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
            result.append(.listItem(String(listItemText)))
        } else if line.contains("[") && line.contains(")") {
            // Extract Markdown link text and URL
            if let linkTextRange = line.range(of: #"\[.*?\]"#, options: .regularExpression),
               let urlRange = line.range(of: #"\(.*?\)"#, options: .regularExpression) {
                
                let linkText = String(line[linkTextRange]).dropFirst().dropLast()
                let url = String(line[urlRange]).dropFirst().dropLast()
                result.append(.link(text: String(linkText), url: String(url)))
            } else {
                result.append(.paragraph(line)) // Fallback in case of invalid link format
            }
        } else {
            result.append(.paragraph(line))
        }
    }

    return result
}
import Speech
import SwiftUI
import AVFoundation

class SpeechRecognizer: ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?

    var onCommandDetected: (() -> Void)?

    func startListening() {
        // Check speech recognition authorization status
        SFSpeechRecognizer.requestAuthorization { authStatus in
            if authStatus != .authorized {
                print("Speech recognition authorization denied")
                return
            }
        }

        // Stop any existing session if it's already running
        if audioEngine.isRunning {
            stopListening()
        }

        // Configure the audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            return
        }

        // Set up the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        // Set up the audio engine input
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString
                self.resetSilenceTimer()
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
                self.sendCommandAfterPause()
            }
        }

        // Configure the audio engine tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start the audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("Audio engine started")
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }

        isListening = true
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        silenceTimer?.invalidate()
    }

    private func startAudioEngine() throws {
        audioEngine.prepare()
        try audioEngine.start()
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
