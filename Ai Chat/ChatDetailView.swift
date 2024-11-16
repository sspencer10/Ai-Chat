import SwiftUI

struct ChatDetailView: View {
    let sessionID: UUID
    @State private var messages: [Message] = []
    
    var body: some View {
        List(messages) { message in
            HStack {
                if message.isUser {
                    Spacer()
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .frame(maxWidth: 250, alignment: .trailing)
                } else {
                    Text(message.content)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: 250, alignment: .leading)
                    Spacer()
                }
            }
        }
        .navigationTitle("Chat Details")
        .onAppear {
            loadMessages()
        }
    }
    
    private func loadMessages() {
        let dbMessages = CoreDataManager.shared.fetchMessages(for: sessionID)
        messages = dbMessages.map { dbMessage in
            Message(content: dbMessage.content ?? "", isUser: dbMessage.isUser)
        }
    }
}
