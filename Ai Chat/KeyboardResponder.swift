import SwiftUI
import Combine

class KeyboardResponder: ObservableObject {
    @Published var isKeyboardVisible: Bool = false
    @Published var keyboardHeight: CGFloat = 0.0
    private let contentClass: ContentClass

    private var cancellableSet: Set<AnyCancellable> = []

    init(contentClass: ContentClass) {
        self.contentClass = contentClass
        print("ContentClass instance in KeyboardResponder: \(ObjectIdentifier(contentClass))")
    
        let keyboardWillShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> (Bool, CGFloat) in
                let height = KeyboardResponder.getKeyboardHeight(from: notification)
                return (true, CGFloat(height)) // Explicitly ensure CGFloat
            }

        let keyboardWillHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in (false, CGFloat(0)) } // Ensure CGFloat type for 0.0

        Publishers.Merge(keyboardWillShow, keyboardWillHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible, height in
                self?.isKeyboardVisible = isVisible
                self?.keyboardHeight = height
            }
            .store(in: &cancellableSet)
    }

    private static func getKeyboardHeight(from notification: Notification) -> CGFloat {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }
        return keyboardFrame.height
    }
}
