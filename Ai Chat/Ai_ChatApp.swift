//
//  Ai_ChatApp.swift
//  Ai Chat
//
//  Created by Steven Spencer on 10/29/24.
//

import SwiftUI

@main
struct Ai_ChatApp: App {
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    applyAppearanceMode()
                }
                .onChange(of: appearanceMode) {
                    applyAppearanceMode()
                }
        }
    }
#if !os(macOS)
    func applyAppearanceMode() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                switch appearanceMode {
                case .system:
                    window.overrideUserInterfaceStyle = .unspecified
                case .light:
                    window.overrideUserInterfaceStyle = .light
                case .dark:
                    window.overrideUserInterfaceStyle = .dark
                }
            }
        }
    }
    #endif
}
