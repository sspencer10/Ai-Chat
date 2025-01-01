import SwiftUI
import Combine

//typealias KeyboardInfo = (isVisible: Bool, height: CGFloat)

//@MainActor
class KeyboardResponder: ObservableObject {
    /*
    @Published var isKeyboardVisible: Bool = false
    @Published var keyboardHeight: CGFloat = 0.0

    private var cancellableSet: Set<AnyCancellable> = []

    init() {
        let keyboardWillShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> KeyboardInfo in
                let height = KeyboardResponder.getKeyboardHeight(from: notification)
                return (true, height)
            }

        let keyboardWillHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> KeyboardInfo in
                return (false, 0.0)
            }

        let keyboardWillChangeFrame = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .map { notification -> KeyboardInfo in
                let height = KeyboardResponder.getKeyboardHeight(from: notification)
                let isVisible = height > 0
                return (isVisible, height)
            }

        Publishers.Merge(keyboardWillShow, keyboardWillHide)
            .merge(with: keyboardWillChangeFrame)
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
            return 0.0
        }
        return keyboardFrame.height
    }
     */
}
