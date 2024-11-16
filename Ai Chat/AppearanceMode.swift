//
//  AppearanceMode.swift
//  Ai Chat
//
//  Created by Steven Spencer on 10/30/24.
//

import Foundation

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { self.rawValue }
}

