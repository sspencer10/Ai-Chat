import Foundation
import SwiftUI

class UserDefaultsManager: ObservableObject {
    
    @Published var selectedModel: String = UserDefaults.standard.string(forKey: "selectedModel") ?? "gpt-4o-mini"
    @Published var selectedVoice: String = UserDefaults.standard.string(forKey: "selectedVoice") ?? "com.apple.ttsbundle.siri_male_en-US_compact"
    @Published var isSpeechEnabled: Bool = UserDefaults.standard.bool(forKey: "isSpeechEnabled")
    @Published var selectedTheme: String = UserDefaults.standard.string(forKey: "selectedTheme") ?? "System"
    @Published var totalSpent: Double = UserDefaults.standard.double(forKey: "totalSpent")
    @Published var cost: String = UserDefaults.standard.string(forKey: "cost") ?? "0.00"
    @Published var showCopiedToast: Bool = UserDefaults.standard.bool(forKey: "showCopiedToast")
    @Published var webSearch: Bool = UserDefaults.standard.bool(forKey: "webSearch")
    @Published var isUpload: Bool = UserDefaults.standard.bool(forKey: "isUpload")


    
    
    init() {
        // Add observer for UserDefaults changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(selectedModelChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(selectedVoiceChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(isSpeechEnabledChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(selectedThemeChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(totalSpentChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(costChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showCopiedToastChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(webSearchChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(isUploadChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
    }
    
    @objc private func isUploadChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isUpload = UserDefaults.standard.bool(forKey: "isUpload")
        }
        
    }
    
    @objc private func showCopiedToastChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showCopiedToast = UserDefaults.standard.bool(forKey: "showCopiedToast")
        }
        
    }
    
    @objc private func webSearchChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.webSearch = UserDefaults.standard.bool(forKey: "webSearch")
        }
        
    }
    
    @objc private func totalSpentChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.totalSpent = UserDefaults.standard.double(forKey: "totalSpent")
        }
    }
    
    @objc private func costChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.cost = UserDefaults.standard.string(forKey: "cost") ?? "0.00"
        }
    }
    
    @objc private func selectedModelChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gpt-4o-mini"
        }
    }
    
    @objc private func selectedVoiceChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.selectedVoice = UserDefaults.standard.string(forKey: "selectedVoice") ?? "com.apple.ttsbundle.siri_male_en-US_compact"
        }
    }
    
    @objc private func isSpeechEnabledChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isSpeechEnabled = UserDefaults.standard.bool(forKey: "isSpeechEnabled")
        }
    }
    
    @objc private func selectedThemeChanged(notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.selectedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? "System"
        }
    }
  
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

