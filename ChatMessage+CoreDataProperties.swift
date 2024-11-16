//
//  ChatMessage+CoreDataProperties.swift
//  Chat with Ai Plus
//
//  Created by Steven Spencer on 10/30/24.
//
//

import Foundation
import CoreData


extension ChatMessage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChatMessage> {
        return NSFetchRequest<ChatMessage>(entityName: "ChatMessage")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var isUser: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var sessionID: UUID?
    @NSManaged public var session: ChatSession?

}

extension ChatMessage : Identifiable {

}
