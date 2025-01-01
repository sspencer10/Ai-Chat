import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    private init() {}

    // Core Data container setup
    let persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ChatModel")  // Replace with your actual model name
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func createSession(title: String) -> ChatSession {
        let context = persistentContainer.viewContext
        let session = ChatSession(context: context)
        session.id = UUID()
        session.sessionTitle = title
        session.timestamp = Date()
        
        do {
            try context.save()
            print("Session saved with title: \(title)")
        } catch {
            print("Failed to save session: \(error)")
        }

        return session
    }
    
    // Function to delete a specific session
    func deleteSession(_ session: ChatSession) {
        let context = persistentContainer.viewContext
        context.delete(session)  // Delete the session object
        
        do {
            try context.save()  // Save changes to persist the deletion
            print("Session deleted successfully.")
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
    
    
    // Function to add a single message to a session
    func addMessage(_ content: String, isUser: Bool, to session: ChatSession) {
        let message = ChatMessage(context: context)
        message.content = content
        message.isUser = isUser
        message.timestamp = Date()
        message.session = session
        saveContext()
    }

    // MARK: - NEW: Batch Add Messages
    /// Adds multiple messages at once to reduce multiple save calls.
    /// - Parameters:
    ///   - messages: Array of `(text, isUser)` tuples to store.
    ///   - session: The `ChatSession` to which these messages belong.
    func batchAddMessages(_ messages: [(text: String, isUser: Bool)], to session: ChatSession) {
        // Use the main context or a background context, depending on your preference.
        // If you prefer background, you can do:
        // let backgroundContext = persistentContainer.newBackgroundContext()
        // and then `backgroundContext.perform { ... }`.
        
        let context = persistentContainer.viewContext
        context.perform {
            for (text, isUser) in messages {
                let chatMessage = ChatMessage(context: context)
                chatMessage.content = text
                chatMessage.isUser = isUser
                chatMessage.timestamp = Date()
                chatMessage.session = session
            }
            
            do {
                try context.save()
                print("Batch of \(messages.count) messages saved successfully.")
            } catch {
                print("Error saving batch messages: \(error)")
            }
        }
    }

    // Fetch all saved chat sessions
    func fetchAllSessions() -> [ChatSession] {
        let request: NSFetchRequest<ChatSession> = ChatSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        do {
            return try persistentContainer.viewContext.fetch(request)
        } catch {
            print("Failed to fetch sessions: \(error)")
            return []
        }
    }

    // Fetch messages associated with a specific session ID
    func fetchMessages(for sessionID: UUID) -> [ChatMessage] {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "session.id == %@", sessionID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        do {
            return try persistentContainer.viewContext.fetch(request)
        } catch {
            print("Failed to fetch messages: \(error)")
            return []
        }
    }

    // Save changes to Core Data
    func saveContext() {
        if persistentContainer.viewContext.hasChanges {
            do {
                try persistentContainer.viewContext.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}
