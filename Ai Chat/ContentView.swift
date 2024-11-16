import SwiftUI
import AVFoundation
import UIKit

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
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
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
                //.padding(.top, 10)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) { // Adjusted spacing between messages
                        ForEach(contentClass.messages) { message in
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    Text(message.content)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .frame(maxWidth: 360, alignment: .trailing)
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
                                    FormattedTextView(message: message.content)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(10)
                                        .frame(maxWidth: 360, alignment: .leading)
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
                                    Spacer()
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                    .onTapGesture {
                        contentClass.hideKeyboard()
                    }
                }
                .onChange(of: contentClass.messages.count) {
                    if let lastMessage = contentClass.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
            
            inputArea
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
    
    var contentOnMac: some View {
        VStack {
            Text("\(contentClass.selectedModel)")
                .font(.caption)
                .foregroundColor(.gray)
                //.padding(.top, 10)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) { // Adjusted spacing between messages
                        ForEach(contentClass.messages) { message in
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
                                } else {
                                    FormattedTextView(message: message.content)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(10)
                                        .frame(maxWidth: 760, alignment: .leading)
                                        .onLongPressGesture(minimumDuration: 1.0) {
                                            UIPasteboard.general.string = message.content
                                            contentClass.triggerToast()
                                        }
                                    Spacer()
                                }
                            }
                            .id(message.id)
                        }
                    }
                }
                .padding()
                .padding(.top, 20)
                .onChange(of: contentClass.messages.count) {
                    if let lastMessage = contentClass.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
                TextField("Enter your question...", text: $contentClass.command, onCommit: {
                    if !contentClass.command.isEmpty {
                        contentClass.sendCommand()
                        contentClass.command = ""
                    }
                })
                .padding(10)
                .background(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                .cornerRadius(12)
                .padding(.leading)

                Button(action: {
                    if speechRecognizer.isListening {
                        speechRecognizer.stopListening()
                    } else {
                        speechRecognizer.startListening()
                    }
                }) {
                    Image(systemName: speechRecognizer.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 24))
                        .padding(10)
                        .background(speechRecognizer.isListening ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                Button(action: {
                    contentClass.sendCommand()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(.trailing)

            }
            .onChange(of: speechRecognizer.recognizedText) {
                contentClass.command = speechRecognizer.recognizedText
            }
            .onAppear {
                speechRecognizer.onCommandDetected = {
                    contentClass.sendCommand()
                    contentClass.command = ""
                }
            }
            .frame(maxWidth: 1000)
            .padding(.vertical, 20)
            .background(Color(.systemGray6))
            .ignoresSafeArea(edges: .bottom)
        }
        .onTapGesture {
            contentClass.hideKeyboard()
        }
    }
    
    var inputAreaOnMac: some View {
        
        VStack {
            HStack {
                TextField("Enter your question...", text: $contentClass.command)
                    .onSubmit {
                        if !contentClass.command.isEmpty {
                            contentClass.sendCommand()
                            contentClass.command = "" // Clear the text field
                        }
                    }

                .padding(10)
                .background(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                .cornerRadius(12)
                .padding(.leading)

                Button(action: {
                    if speechRecognizer.isListening {
                        speechRecognizer.stopListening()
                    } else {
                        speechRecognizer.startListening()
                    }
                    contentClass.hideKeyboard()
                }) {
                    Image(systemName: speechRecognizer.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 24))
                        .padding(10)
                        .background(speechRecognizer.isListening ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                Button(action: {
                    contentClass.sendCommand()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(.trailing)

            }
            .onChange(of: speechRecognizer.recognizedText) {
                contentClass.command = speechRecognizer.recognizedText
            }
            .onAppear {
                speechRecognizer.onCommandDetected = {
                    contentClass.sendCommand()
                    contentClass.command = ""
                }
            }
            //.frame(maxWidth: 1000)
            .padding(.vertical, 20)
            .background(Color(.systemGray6))
            //.ignoresSafeArea(edges: .bottom)
        }
        .onTapGesture {
            contentClass.hideKeyboard()
        }
        

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
