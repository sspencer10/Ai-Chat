//
//  Messages.swift
//  Ai Chat
//
//  Created by Steven Spencer on 10/30/24.
//

import Foundation

// Chat message model
struct Message: Identifiable, Equatable {
    let id = UUID()
    //let content: String
    var content: String
    let isUser: Bool  // true for user messages, false for assistant responses
}
