import SwiftUI
struct MainContent: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ObservedObject var contentClass: ContentClass
    @ObservedObject var speechRecognizer: SpeechRecognizer // Changed to @ObservedObject
    @ObservedObject var speechSynthesizer: SpeechSynthesizer // Changed to @ObservedObject
    @ObservedObject var keyboardResponder: KeyboardResponder
    @State private var showCopiedToast = false
    @State private var text: String = ""
    @State private var height: CGFloat = 50
    @State var keyboardHeight: CGFloat = 0.0
    
    init(contentClass: ContentClass, speechRecognizer: SpeechRecognizer, speechSynthesizer: SpeechSynthesizer, keyboardResponder: KeyboardResponder) {
        self.contentClass = contentClass
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
        self.keyboardResponder = keyboardResponder

    }
    var body: some View {
        GeometryReader { geometry in
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
                
                    
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                if !contentClass.isDeviceListening {
                                    ForEach(contentClass.messages) { message in
                                        MessageView(message: message, contentClass: contentClass)
                                            .id(message.id)
                                    }
                                    if keyboardResponder.isKeyboardVisible {
                                        Color.clear
                                            .frame(height: keyboardHeight)
                                            .id("aboveBottomAnchor")
                                    }
                                    
                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottom")
                                    
                                } else {
                                    PulsingMicrophoneView(contentClass: contentClass, speechRecognizer: speechRecognizer, speechSynthesizer: speechSynthesizer)
                                        .padding(.top, isPortrait(geometry) ? height(geometry) : 0) // Apply top padding in portrait
                                }
                            }
                            .padding()
                        }
                        
                        .coordinateSpace(name: "scrollView")
                        
                        .onChange(of: contentClass.messages.count) {
                            contentClass.scrollToBottom(proxy: scrollProxy)
                        }
                        
                        .onChange(of: keyboardResponder.keyboardHeight) {
                            keyboardHeight = keyboardResponder.keyboardHeight
                        }
                        
                        .onChange(of: contentClass.isDeviceListening) {
                            if contentClass.isDeviceListening {
                                contentClass.scrollTop(proxy: scrollProxy)
                            } else {
                                contentClass.scrollToBottom(proxy: scrollProxy)
                            }
                        }
                        
                        .onChange(of: keyboardResponder.isKeyboardVisible) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("keyboard visibility changed")
                                if keyboardResponder.isKeyboardVisible {
                                    print("keyboard visibility true")
                                    contentClass.scrollToBottom(proxy: scrollProxy)
                                } else {
                                    print("keyboard visibility false")
                                    contentClass.scrollToBottomBottom(proxy: scrollProxy)
                                }
                            }
                        }
                        

                        
                        .onAppear {
                            contentClass.proxySetter(scrollProxy)
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
                
                InputArea(contentClass: contentClass, speechRecognizer: speechRecognizer, speechSynthesizer: speechSynthesizer, keyboardResponder: keyboardResponder)
            }
        }
        .navigationTitle("AI Chat") // Updated to the newer modifier
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            contentClass.hideKeyboard()
        }
        
    }
    
    
    func isPortrait(_ geometry: GeometryProxy) -> Bool {
        geometry.size.height > geometry.size.width
    }
    
    func height(_ geometry: GeometryProxy) -> CGFloat {
        print(geometry.size.height * 0.25)
        return geometry.size.height * 0.25
    }
}

#Preview {
    MainContent(contentClass: ContentClass(), speechRecognizer: SpeechRecognizer(contentClass: ContentClass()), speechSynthesizer: SpeechSynthesizer(contentClass: ContentClass()), keyboardResponder: KeyboardResponder(contentClass: ContentClass()))
}
