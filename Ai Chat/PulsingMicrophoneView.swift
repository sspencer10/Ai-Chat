import SwiftUI
struct PulsingMicrophoneView: View {
    @State private var isPulsing1 = false
    @State private var isPulsing2 = false
    @ObservedObject var contentClass: ContentClass
    @ObservedObject var speechRecognizer: SpeechRecognizer // Changed to @ObservedObject
    @ObservedObject var speechSynthesizer: SpeechSynthesizer // Changed to @ObservedObject
    init(contentClass: ContentClass, speechRecognizer: SpeechRecognizer, speechSynthesizer: SpeechSynthesizer) {
        self.contentClass = contentClass
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
    }
    var body: some View {
        ZStack {
            // First Pulsing Circle
            Circle()
                .stroke(lineWidth: 1)
                .foregroundColor(Color.red.opacity(0.3))
                .scaleEffect(isPulsing1 ? 1.3 : 1.0)
                .opacity(isPulsing1 ? 0 : 0.6)
                .animation(
                    .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                    value: isPulsing1
                )

            // Second Pulsing Circle
            Circle()
                .stroke(lineWidth: 1)
                .foregroundColor(Color.red.opacity(0.3))
                .scaleEffect(isPulsing2 ? 1.6 : 1.0)
                .opacity(isPulsing2 ? 0 : 0.6)
                .animation(
                    .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: isPulsing2
                )

            // Base Circle
            Circle()
                .stroke(lineWidth: 4)
                .foregroundColor(Color.red.opacity(0.5))
                .frame(width: 90, height: 90)

            // Microphone Icon
            Image(systemName: "mic.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.red)
        }
        .frame(width: 120, height: 120)
        .fixedSize() // Prevents unwanted resizing
        .onAppear {
            isPulsing1 = true
            isPulsing2 = true
        }
        .onTapGesture {
            print("tapped")
            toggleSpeech()
        }
    }
    // Refactored toggle action
    func toggleSpeech() {
        if speechRecognizer.isListening {
            print("Stop")
            speechRecognizer.stopListening()
        } else {
            print("Start")
            contentClass.hideKeyboard()
            speechRecognizer.startListening()
        }
    }
}
