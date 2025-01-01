import SwiftUI
import Combine
import AVFoundation

// MARK: - ScrollOffsetPreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - MainContent View
struct MainContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject var contentClass: ContentClass
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @ObservedObject var speechSynthesizer: SpeechSynthesizer
    @State private var showCopiedToast = false
    @State private var showAlert: Bool = false
    @State private var scrollToBottom: (() -> Void)?
    @State private var scrollToTop: (() -> Void)?
    @State private var scrollUserUp: (() -> Void)?
    @State private var isAtBottom = true
    @State private var scrollOffset: CGFloat = 0
    @State private var cancellables = Set<AnyCancellable>()
    @StateObject var userDefaultsManager = UserDefaultsManager()
    @StateObject var keyboardResponder = KeyboardResponder()
    @State var command: String = ""

    init(contentClass: ContentClass, speechRecognizer: SpeechRecognizer, speechSynthesizer: SpeechSynthesizer) {
        self.contentClass = contentClass
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
    }

    let allSentences = [
        "Give me directions to...",
        "Set an alarm for 6:00",
        "Analyze the uploaded file ...",
        "Get current news links from https://...",
        "Search the web for ...",
        "What is the weather tomorrow in ...",
        "Help me diagnose my illness"
    ]
    
    var randomSentences: [String] {
        Array(allSentences.shuffled().prefix(4))
    }
    
    var body: some View {
        ZStack {
            VStack {
                if !contentClass.isDeviceListening {
                    // show either tips or messages
                    if contentClass.messages.isEmpty {
                        // show tips
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer()
                            LazyVStack(alignment: .leading, spacing: 8) {

                                ForEach(randomSentences, id: \.self) { sentence in
                                    Text("\"\(sentence)\"")
                                        .font(.headline)
                                        .italic()
                                        .foregroundColor(.gray)
                                    Text(" ")
                                }
                            }
                            .id(contentClass.messages.count)
                            .padding(.leading, 40)
                            Spacer()
                            Spacer()
                        }
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.gray)
                            .font(.headline)
                    } else {
                        // show messages
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(contentClass.messages, id: \.id) { msg in
                                        MessageView(message: msg, contentClass: contentClass)
                                            .id(msg.id)
                                    }
                                    
                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottom")
                                }
                                .id(contentClass.messages.count)
                            }
                            .padding(.top, 20)
                            .padding()
                            .onAppear {
                                setupScrolling(scrollProxy: scrollProxy)
                            }
                        }
                        .coordinateSpace(name: "scrollView") // Assign a named coordinate space
                    }
                } else {
                    // show microphone
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            PulsingMicrophoneView(contentClass: contentClass, speechRecognizer: speechRecognizer, speechSynthesizer: speechSynthesizer)
                                .padding(.top, 5)
                            Spacer()
                        }
                        Spacer()
                    }
                }

                Spacer()
                // Typing Indicator
                if contentClass.isTyping {
                    TypingIndicatorView()
                        .transition(.opacity)
                        .padding(.bottom, 10)
                        .accessibilityLabel("Assistant is typing")
                }
                
                // Input Area
                InputArea(
                    contentClass: contentClass,
                    speechRecognizer: speechRecognizer,
                    speechSynthesizer: speechSynthesizer,
                    command: $command
                )
            }
        }
                    
    
            .onChange(of: contentClass.messages) {
                // Print the latest message to the console
                if let latestMessage = contentClass.messages.last {
                    if !latestMessage.isUser {
                        scrollUserUp?()
                    }
                }
            }
    
            .alert("Action Required", isPresented: $showAlert) {
                Button("Confirm") {
                    print("Custom action triggered")
                }
                Button("Cancel", role: .cancel) {
                    print("Cancel action triggered")
                }
            } message: {
                Text("Would you like to proceed with this action?")
            }
        
            .onChange(of: contentClass.showAlert) {
                showAlert = contentClass.showAlert
            }
        
            .onChange(of: userDefaultsManager.webSearch) {
                print("Navigation title changed to \(navTitle())")
            }
        
            .onChange(of: userDefaultsManager.showCopiedToast) {
                print("Navigation title changed to \(navTitle())")
            }
        
            .onChange(of: speechRecognizer.isListening) {
                if speechRecognizer.isListening {
                    scrollToBottom?()
                } else {
                    scrollToTop?()
                }
            }
        
            .onChange(of: UIApplication.shared.isKeyboardVisible ) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    scrollToBottom?()
                }
            }
        
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        
            .navigationTitle(navTitle())
            .navigationBarTitleDisplayMode(.inline)
    }
    
    func navTitle() -> String {
        var title: String = ""
        let showCopied: Bool = UserDefaults.standard.bool(forKey: "showCopiedToast")
        
        if userDefaultsManager.webSearch {
            title = "Web Search"
        } else if showCopied {
            title = "Copied to clipboard"
        } else {
            title = "Chat"
        }
        
        return title
    }

    private func setupScrolling(scrollProxy: ScrollViewProxy) {
        scrollToBottom = {
            if let lastID = self.contentClass.messages.last?.id {
                scrollProxy.scrollTo(lastID, anchor: .bottom)
            }
        }
        scrollToTop = {
            if let firstID = self.contentClass.messages.first?.id {
                scrollProxy.scrollTo(firstID, anchor: .top)
            }
        }
        scrollUserUp = {
            if let userID = self.contentClass.messages.last?.id {
                print("Scrolling to user message with id: \(userID)")
                scrollProxy.scrollTo(userID, anchor: .top)
            }
        }
    }
    
}

#Preview {
    MainContent(
        contentClass: ContentClass(),
        speechRecognizer: SpeechRecognizer(
            contentClass: ContentClass(),
            audioPlayerManager: AudioPlayerManager(contentClass: ContentClass())
        ),
        speechSynthesizer: SpeechSynthesizer(contentClass: ContentClass())
    )
}
