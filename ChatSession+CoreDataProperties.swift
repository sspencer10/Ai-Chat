//
//  ChatSession+CoreDataProperties.swift
//  Chat with Ai Plus
//
//  Created by Steven Spencer on 10/30/24.
//
//

import Foundation
import CoreData


extension ChatSession {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChatSession> {
        return NSFetchRequest<ChatSession>(entityName: "ChatSession")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var sessionTitle: String?
    @NSManaged public var messages: ChatMessage?

}

extension ChatSession : Identifiable {

}
