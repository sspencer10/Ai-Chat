
import UIKit
import SwiftUI

class DynamicHeightTextEditorClass: UITextView {
    var sessionID: String?
    override func becomeFirstResponder() -> Bool {
        sessionID = UUID().uuidString
        guard let inputSessionID = self.sessionID else {
            print("Error: Missing session ID")
            return false
        }
        print("Input Session ID: \(inputSessionID)")
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        print("DynamicHeightTextEditor is resigning first responder.")
        sessionID = nil
        return super.resignFirstResponder()
    }
}

struct DynamicHeightTextEditor: UIViewRepresentable {
    @Binding var command: String
    @Binding var bindedFocus: Bool
    @Binding var height: CGFloat
    let maxLines: Int = 4

    
    func makeUIView(context: Context) -> DynamicHeightTextEditorClass {
        let textView = DynamicHeightTextEditorClass()
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 5, bottom: 5, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.text = command
        return textView
    }

    
    func updateUIView(_ uiView: DynamicHeightTextEditorClass, context: Context) {
        if command != "" {
            context.coordinator.updateCount += 1 // Update the counter in the Coordinator
        }
        
        if context.coordinator.updateCount > 1 {
            uiView.text = command
        }
        if bindedFocus {
            if !uiView.isFirstResponder {
                _ = uiView.becomeFirstResponder()
            }
        } else {
            if uiView.isFirstResponder {
                _ = uiView.resignFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func calculateTextboxHeight(for textView: UITextView) -> CGFloat {
        let lineHeight = textView.font?.lineHeight ?? 22 // Use font's line height or default to 22
        let contentHeight = textView.contentSize.height
        let lineCount = max(Int(contentHeight / lineHeight), 1)
        return CGFloat(min(lineCount, maxLines)) * lineHeight
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: DynamicHeightTextEditor
        var updateCount = 0 // Mutable counter inside the Coordinator

        private var debounceTask: DispatchWorkItem?

        init(_ parent: DynamicHeightTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // Cancel any existing debounce task
            debounceTask?.cancel()

            // Create a new debounce task
            debounceTask = DispatchWorkItem { [weak self] in
                guard let self = self else { return }

                // Update text binding only if it has changed
                if self.parent.command != textView.text {
                    DispatchQueue.main.async {
                        self.parent.command = textView.text
                        //print("updated text")
                    }
                }

                // Calculate the new height
                let newHeight = self.parent.calculateTextboxHeight(for: textView)

                // Update height binding only if it has changed
                if self.parent.height != newHeight {
                    DispatchQueue.main.async {
                        self.parent.height = newHeight
                        //print("updated height")
                    }
                }
            }

            // Execute the debounce task after a delay (e.g., 100ms)
            if let task = debounceTask {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: task)
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.bindedFocus {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.bindedFocus = false
                }
            }
        }
    }
}

extension UIApplication {
    private static var _isKeyboardVisible: Bool = false

    var isKeyboardVisible: Bool {
        return UIApplication._isKeyboardVisible
    }

    func observeFirstResponderChanges() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            UIApplication._isKeyboardVisible = true
            self?.logFirstResponder()
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            UIApplication._isKeyboardVisible = false
            self?.logFirstResponder()
        }
    }
    
    func currentFirstResponder() -> UIResponder? {
        UIResponder.currentResponder = nil // Reset the responder
        self.sendAction(#selector(UIResponder.findFirstResponder), to: nil, from: nil, for: nil)
        return UIResponder.currentResponder
    }

    private func logFirstResponder() {
        if let firstResponder = self.currentFirstResponder() {
            print("Current First Responder: \(firstResponder)")
        } else {
            print("No current first responder.")
        }
    }

    func stopObservingFirstResponderChanges() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}
extension UIResponder {
    private static weak var _currentResponder: UIResponder?

    @objc func findFirstResponder() {
        UIResponder._currentResponder = self
    }

    static var currentResponder: UIResponder? {
        get { _currentResponder }
        set { _currentResponder = newValue }
    }
}
