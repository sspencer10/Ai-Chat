import SwiftUI

struct MicView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {


            // Microphone Icon
            Image(systemName: "mic.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.red)

            // Base Circle
            Circle()
                .stroke(lineWidth: 4)
                .frame(width: 90, height: 90)
                .foregroundColor(.red.opacity(0.5))
        }

    }
}

