import SwiftUI

@main
struct Ai_ChatApp: App {
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
    @StateObject var contentClass: ContentClass
    @StateObject var speechRecognizer: SpeechRecognizer
    @StateObject var speechSynthesizer: SpeechSynthesizer
    @StateObject var keyboardResponder: KeyboardResponder
    @State private var currentURL: URL?
    @State var searchTerm: String = ""

    // Initialize objects in the App initializer
    init() {
        let sharedContentClass = ContentClass()
        let sharedSpeechSynthesizer = SpeechSynthesizer(contentClass: sharedContentClass)
        let sharedSpeechRecognizer = SpeechRecognizer(contentClass: sharedContentClass)
        let sharedKeyboardResponder = KeyboardResponder(contentClass: sharedContentClass)

        _contentClass = StateObject(wrappedValue: sharedContentClass)
        _speechSynthesizer = StateObject(wrappedValue: sharedSpeechSynthesizer)
        _speechRecognizer = StateObject(wrappedValue: sharedSpeechRecognizer)
        _keyboardResponder = StateObject(wrappedValue: sharedKeyboardResponder)

        // Inject the shared SpeechSynthesizer into ContentClass
        sharedContentClass.setSpeechSynthesizer(sharedSpeechSynthesizer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                contentClass: contentClass,
                speechRecognizer: speechRecognizer,
                speechSynthesizer: speechSynthesizer,
                keyboardResponder: keyboardResponder
            )
            .onOpenURL { url in
                currentURL = url
                handleURL(url)
            }
            .onAppear {
                applyAppearanceMode()
                print("ContentClass instance in Ai_ChatApp: \(ObjectIdentifier(contentClass))")
            }
            .onChange(of: appearanceMode) {
                applyAppearanceMode()
            }
        }
    }
    
    func handleURL(_ url: URL) {
        print("handleURL")
        if url.scheme == "chatai" {
            print("is chatai")
            print("Host: \(url.host ?? "None")")
            if url.host == "search" {
                print("search")
                if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems {
                    for item in queryItems {
                        if item.name == "q" {
                            print("search term \(item.value ?? "")")
                            searchTerm = item.value ?? ""
                            contentClass.command = searchTerm
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                contentClass.sendCommand(isUpload: false)
                                contentClass.isSpeechEnabled = true
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("should listen")
                    speechRecognizer.toggleListening()
                    contentClass.isSpeechEnabled = true
                }
            }
        }
    }
    
#if !os(macOS)
    func applyAppearanceMode() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                switch appearanceMode {
                case .system:
                    window.overrideUserInterfaceStyle = .unspecified
                case .light:
                    window.overrideUserInterfaceStyle = .light
                case .dark:
                    window.overrideUserInterfaceStyle = .dark
                }
            }
        }
    }
#endif
}
