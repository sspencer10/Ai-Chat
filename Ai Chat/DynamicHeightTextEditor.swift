import SwiftUI

struct DynamicHeightTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 5, left: 5, bottom: 0, right: 0) // Add top padding
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.delegate = context.coordinator
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal) // Prevent horizontal growth
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.font = UIFont.systemFont(ofSize: 16)

        // Ensure width is fixed and height adjusts dynamically
        let fixedWidth = uiView.frame.width
        //print("fixedWidth: \(fixedWidth)")
        let size = uiView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        //print("size height \(size.height)")
        //print("hight-- \(height)")
        DispatchQueue.main.async {
            if size.height < 67 {
                height = size.height
            } else {
                height = CGFloat(66)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: DynamicHeightTextEditor

        init(_ parent: DynamicHeightTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}
