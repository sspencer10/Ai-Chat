import SwiftUI
import CoreData

struct ChatSessionsView: View {
    @Environment(\.presentationMode) var presentationMode
    let onSelectSession: (ChatSession) -> Void // Closure to handle session selection
    @State private var sessions: [ChatSession] = []
    @State private var isEditing: Bool = false // Track editing mode
    @State private var editingSessionTitle: [UUID: String] = [:] // Track session titles being edited

    var body: some View {
        NavigationView {
            List {
                ForEach(sessions, id: \.id) { session in
                    VStack(alignment: .leading) {
                        if isEditing {
                            // Show the TextField in editing mode
                            if let sessionId = session.id {
                                TextField("Edit title", text: Binding(
                                    get: {
                                        editingSessionTitle[sessionId] ?? (session.sessionTitle ?? "")
                                    },
                                    set: { newValue in
                                        editingSessionTitle[sessionId] = newValue
                                    }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .submitLabel(.done) // Change the return key to show "Save"
                                .onSubmit {
                                    updateSessionTitle(for: session)
                                }
                                .padding()
                            } else {
                                Text("Invalid Session ID") // Fallback for unexpected nil UUID
                            }
                        } else {
                            // Display session title
                            Text("\(session.sessionTitle ?? "No Title")")
                                .font(.headline)
                                .onTapGesture {
                                    onSelectSession(session)  // Load the session on tap
                                    presentationMode.wrappedValue.dismiss()  // Dismiss view after selection
                                }
                        }
                        Text("Date: \(session.timestamp ?? Date(), formatter: DateFormatter.short)")
                            .font(.subheadline)
                    }
                    .padding()
                }
                .onDelete(perform: deleteSession) // Enable delete action
            }
            .navigationBarTitle("Chat Sessions", displayMode: .inline)
            .navigationBarItems(trailing: HStack {
                Button(action: {
                    isEditing.toggle() // Toggle editing state
                    if !isEditing {
                        // Reset editingSessionTitle when done editing
                        editingSessionTitle.removeAll()
                    }
                }) {
                    Text(isEditing ? "Done" : "Edit")
                        .foregroundColor(.blue)
                }
            })
            .onAppear {
                sessions = CoreDataManager.shared.fetchAllSessions() // Fetch all saved sessions
            }
        }
    }

    private func updateSessionTitle(for session: ChatSession) {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        if let sessionId = session.id {  // Ensure session ID is not nil
            session.sessionTitle = editingSessionTitle[sessionId] // Update the session title
            do {
                try context.save() // Save changes to Core Data
                print("Session title updated to: \(editingSessionTitle[sessionId] ?? "")")
            } catch {
                print("Failed to update session title: \(error.localizedDescription)")
            }
            // Clear the editing title for this session
            editingSessionTitle[sessionId] = nil
            sessions = CoreDataManager.shared.fetchAllSessions() // Refresh the session list
        }
    }

    // Function to handle deletion of sessions
    private func deleteSession(at offsets: IndexSet) {
        offsets.forEach { index in
            let sessionToDelete = sessions[index]
            CoreDataManager.shared.deleteSession(sessionToDelete) // Delete from Core Data
        }
        sessions = CoreDataManager.shared.fetchAllSessions() // Refresh the session list
    }
}

// Date formatter for display extension
extension DateFormatter {
    static var short: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}
