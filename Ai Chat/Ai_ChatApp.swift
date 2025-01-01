import SwiftUI
import Firebase

@main
struct Ai_ChatApp: App {
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
    @StateObject var contentClass: ContentClass
    @StateObject var speechRecognizer: SpeechRecognizer
    @StateObject var speechSynthesizer: SpeechSynthesizer
    @State private var currentURL: URL?
    @State var searchTerm: String = ""

    init() {
        FirebaseApp.configure()
        let sharedContentClass = ContentClass()
        let sharedAudioPlayerManager = AudioPlayerManager(contentClass: sharedContentClass)
        let sharedSpeechSynthesizer = SpeechSynthesizer(contentClass: sharedContentClass)
        let sharedSpeechRecognizer = SpeechRecognizer(contentClass: sharedContentClass, audioPlayerManager: sharedAudioPlayerManager)

        _contentClass = StateObject(wrappedValue: sharedContentClass)
        _speechSynthesizer = StateObject(wrappedValue: sharedSpeechSynthesizer)
        _speechRecognizer = StateObject(wrappedValue: sharedSpeechRecognizer)

        // Inject the shared SpeechSynthesizer into ContentClass
        sharedContentClass.setSpeechSynthesizer(sharedSpeechSynthesizer)
        sharedAudioPlayerManager.setSpeechRecognizer(sharedSpeechRecognizer)

        // Set navigation bar appearance
        setupNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                contentClass: contentClass,
                speechRecognizer: speechRecognizer,
                speechSynthesizer: speechSynthesizer
            )
            .onOpenURL { url in
                currentURL = url
                handleURL(url)
            }
            .onAppear {
                applyAppearanceMode()
            }
            .onChange(of: appearanceMode) {
                applyAppearanceMode()
            }
        }
    }
    
    func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = UIColor.systemGray6
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        // Apply appearance globally to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Ensure the navigation bar is not translucent
        UINavigationBar.appearance().isTranslucent = false
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                contentClass.sendCommand(isUpload: false, command: searchTerm)
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
}
