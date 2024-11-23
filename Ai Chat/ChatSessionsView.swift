import SwiftUI
import CoreData
import PDFKit
import WebKit
import Down // Ensure this is added to your project via Swift Package Manager or CocoaPods

// MARK: - ChatSessionsView
struct ChatSessionsView: View {
    @Environment(\.presentationMode) var presentationMode
    let onSelectSession: (ChatSession) -> Void // Closure to handle session selection
    @State private var sessions: [ChatSession] = []
    @State private var isEditing: Bool = false // Track editing mode
    @State private var editingSessionTitle: [UUID: String] = [:] // Track session titles being edited
    
    // State variables for sharing
    @State private var sessionToShare: ChatSession? = nil
    @State private var showShareOptions: Bool = false
    @State private var shareItems: [Any]? = nil
    @State private var pdfGenerator: PDFGenerator? = nil // Retain PDFGenerator instance
    
    // State variables for alerts
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sessions, id: \.id) { session in
                    HStack {
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
                                    .padding(.vertical, 4)
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
                            // Display session date
                            Text("Date: \(DateFormatter.short.string(from: session.timestamp ?? Date()))")
                                .font(.subheadline)
                        }
                        Spacer()
                        // Share button with action sheet
                        shareButton(for: session)
                    }
                    .padding(.vertical, 8)
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
            // Present the ShareSheet when shareItems is set
            .sheet(item: Binding(
                get: {
                    shareItems != nil ? UUIDWrapper() : nil
                },
                set: { newValue in
                    if newValue == nil {
                        shareItems = nil
                        pdfGenerator = nil // Release PDFGenerator instance after sharing
                    }
                }
            )) { _ in
                if let items = shareItems {
                    ShareSheet(activityItems: items)
                }
            }
            // Present the alert if needed
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Share Button with Action Sheet
    @ViewBuilder
    private func shareButton(for session: ChatSession) -> some View {
        Button(action: {
            sessionToShare = session
            showShareOptions = true
        }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.blue)
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel("Share Session")
        .accessibilityHint("Share this chat session")
        .actionSheet(isPresented: $showShareOptions) {
            ActionSheet(title: Text("Share Session"),
                        message: Text("Choose a format to share your session."),
                        buttons: [
                            /*
                .default(Text("HTML")) {
                    if let session = sessionToShare {
                        if let htmlFileURL = prepareShareContentHTML(for: session) {
                            shareItems = [htmlFileURL]
                        } else {
                            alertMessage = "Failed to generate HTML content."
                            showAlert = true
                        }
                    }
                },*/
                .default(Text("PDF")) {
                    if let session = sessionToShare {
                        generatePDF(for: session)
                    }
                },
                .cancel()
            ])
        }
    }
    
    // MARK: - Generate PDF Function
    private func generatePDF(for session: ChatSession) {
        // Fetch the HTML content for the session
        guard let sessionId = session.id else {
            alertMessage = "Invalid session ID."
            showAlert = true
            return
        }
        
        let messages = CoreDataManager.shared.fetchMessages(for: sessionId)
        
        // Build the HTML content
        var htmlContent = """
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                @page {
                    size: A4;
                    margin: 20mm;
                }
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif; 
                    padding: 0;
                    margin: 0;
                    width: 100%;
                    box-sizing: border-box;
                    background-color: #f5f5f5;
                }
                .container {
                    padding: 20px; /* Added padding */
                }
                .session-title { 
                    font-size: 24px; 
                    font-weight: bold; 
                    margin-bottom: 10px; 
                    color: #2F80ED;
                }
                .session-date { 
                    font-size: 14px; 
                    color: gray; 
                    margin-bottom: 20px; 
                }
                .messages { 
                    display: flex; 
                    flex-direction: column; 
                    gap: 10px; 
                }
                .message {
                    max-width: 80%;
                    padding: 10px 16px;
                    border-radius: 20px;
                    position: relative;
                    word-wrap: break-word;
                }
                .user {
                    align-self: flex-end;
                    background-color: #2F80ED;
                    color: white;
                    border-bottom-right-radius: 0;
                }
                .assistant {
                    align-self: flex-start;
                    background-color: #E5E5EA;
                    color: black;
                    border-bottom-left-radius: 0;
                }
                .timestamp {
                    font-size: 12px;
                    color: gray;
                    margin-top: 4px;
                }
                /* Override timestamp color for user messages */
                .user .timestamp {
                    color: white;
                }
                .message p {
                    margin: 0;
                    line-height: 1.5;
                }
                /* Styling for inline code snippets */
                code {
                    background-color: #e0e0e0;
                    padding: 2px 4px;
                    border-radius: 4px;
                    font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
                    white-space: pre-wrap;
                    word-wrap: break-word;
                    max-width: 100%;
                    display: inline-block;
                    box-sizing: border-box;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="session-title">Session Title: \(session.sessionTitle ?? "No Title")</div>
                <div class="session-date">Date: \(DateFormatter.short.string(from: session.timestamp ?? Date()))</div>
                <div class="messages">
        """
        
        // Add messages
        for message in messages {
            let senderClass = message.isUser ? "user" : "assistant"
            let timestamp = DateFormatter.short.string(from: message.timestamp ?? Date())
            let markdownContent = message.content ?? ""
            
            // Convert Markdown to HTML using Down
            let htmlString: String
            do {
                let down = Down(markdownString: markdownContent)
                htmlString = try down.toHTML()
                print("Converted HTML String: \(htmlString)")
            } catch {
                print("Failed to convert Markdown to HTML for message ID: \(message.id ?? UUID()). Error: \(error.localizedDescription)")
                // Fallback to raw Markdown with HTML escaping
                htmlString = "<p>\(markdownContent.htmlEscaped)</p>"
            }
            
            htmlContent += """
            <div class="message \(senderClass)">
                \(htmlString)
                <div class="timestamp">\(timestamp)</div>
            </div>
            """
        }
        
        // Close HTML tags
        htmlContent += """
                </div>
            </div>
        </body>
        </html>
        """
        
        // Add this print statement to verify HTML content
        print("Generated HTML Content:\n\(htmlContent)")
        
        // Initialize PDFGenerator and retain it
        pdfGenerator = PDFGenerator(htmlContent: htmlContent) { pdfURL in
            if let url = pdfURL {
                DispatchQueue.main.async {
                    self.shareItems = [url]
                }
            } else {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to generate PDF."
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - Prepare Share Content as HTML File with Message Bubbles
    private func prepareShareContentHTML(for session: ChatSession) -> URL? {
        guard let sessionId = session.id else {
            return nil
        }
        
        // Fetch messages related to the session from Core Data
        let messages = CoreDataManager.shared.fetchMessages(for: sessionId)
        
        // Start building the HTML content
        var htmlContent = """
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                @page {
                    size: A4;
                    margin: 20mm;
                }
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif; 
                    padding: 0;
                    margin: 0;
                    width: 100%;
                    box-sizing: border-box;
                    background-color: #f5f5f5;
                }
                .container {
                    padding: 20px; /* Added padding */
                }
                .session-title { 
                    font-size: 24px; 
                    font-weight: bold; 
                    margin-bottom: 10px; 
                    color: #2F80ED;
                }
                .session-date { 
                    font-size: 14px; 
                    color: gray; 
                    margin-bottom: 20px; 
                }
                .messages { 
                    display: flex; 
                    flex-direction: column; 
                    gap: 10px; 
                }
                .message {
                    max-width: 80%;
                    padding: 10px 16px;
                    border-radius: 20px;
                    position: relative;
                    word-wrap: break-word;
                }
                .user {
                    align-self: flex-end;
                    background-color: #2F80ED;
                    color: white;
                    border-bottom-right-radius: 0;
                }
                .assistant {
                    align-self: flex-start;
                    background-color: #E5E5EA;
                    color: black;
                    border-bottom-left-radius: 0;
                }
                .timestamp {
                    font-size: 12px;
                    color: gray;
                    margin-top: 4px;
                }
                /* Override timestamp color for user messages */
                .user .timestamp {
                    color: white;
                }
                .message p {
                    margin: 0;
                    line-height: 1.5;
                }
                /* Styling for inline code snippets */
                code {
                    background-color: #e0e0e0;
                    padding: 2px 4px;
                    border-radius: 4px;
                    font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
                    white-space: pre-wrap;
                    word-wrap: break-word;
                    max-width: 100%;
                    display: inline-block;
                    box-sizing: border-box;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="session-title">Session Title: \(session.sessionTitle ?? "No Title")</div>
                <div class="session-date">Date: \(DateFormatter.short.string(from: session.timestamp ?? Date()))</div>
                <div class="messages">
        """
        
        // Add messages
        for message in messages {
            let senderClass = message.isUser ? "user" : "assistant"
            let timestamp = DateFormatter.short.string(from: message.timestamp ?? Date())
            let markdownContent = message.content ?? ""
            
            // Convert Markdown to HTML using Down
            let htmlString: String
            do {
                let down = Down(markdownString: markdownContent)
                htmlString = try down.toHTML()
                print("Converted HTML String: \(htmlString)")
            } catch {
                print("Failed to convert Markdown to HTML for message ID: \(message.id ?? UUID()). Error: \(error.localizedDescription)")
                // Fallback to raw Markdown with HTML escaping
                htmlString = "<p>\(markdownContent.htmlEscaped)</p>"
            }
            
            htmlContent += """
            <div class="message \(senderClass)">
                \(htmlString)
                <div class="timestamp">\(timestamp)</div>
            </div>
            """
        }
        
        // Close HTML tags
        htmlContent += """
                </div>
            </div>
        </body>
        </html>
        """
        
        // Save HTML content to a temporary .html file
        let tempDirectory = FileManager.default.temporaryDirectory
        let sanitizedTitle = session.sessionTitle?
            .replacingOccurrences(of: " ", with: "_")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined() ?? "session"
        let fileName = "\(sanitizedTitle).html"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("HTML file saved at: \(fileURL)") // Debugging
            
            // Schedule deletion after sharing (e.g., 60 seconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("Temporary HTML file deleted: \(fileURL)")
                } catch {
                    print("Failed to delete temporary HTML file: \(error.localizedDescription)")
                }
            }
            
            return fileURL
        } catch {
            print("Failed to write HTML file: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Update Session Title Function
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
    
    // MARK: - Delete Session Function
    private func deleteSession(at offsets: IndexSet) {
        offsets.forEach { index in
            let sessionToDelete = sessions[index]
            CoreDataManager.shared.deleteSession(sessionToDelete) // Delete from Core Data
        }
        sessions = CoreDataManager.shared.fetchAllSessions() // Refresh the session list
    }
}

// MARK: - ShareSheet Struct
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var completion: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            completion?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static var short: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current // Ensures dates are formatted according to the user's locale
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Identifiable Wrapper for Sheet
struct UUIDWrapper: Identifiable {
    let id = UUID()
}

// MARK: - String Extension for HTML Escaping
extension String {
    var htmlEscaped: String {
        let replacements: [String: String] = [
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            "\"": "&quot;",
            "'": "&#39;"
        ]
        var escaped = self
        for (original, replacement) in replacements {
            escaped = escaped.replacingOccurrences(of: original, with: replacement)
        }
        return escaped
    }
}
