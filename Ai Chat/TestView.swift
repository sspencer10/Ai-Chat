import SwiftUI
struct TestView: View {
        @State private var yourText: String = "YOUR PLACEHOLDER TEXT"
    @State var noText: String = "No Text"
    @State var testBool: Bool = true
    @State var text: String = "Text"
        var body: some View {
            TextField(testBool ? noText : yourText, text: $text)
                .padding()
                .background(Color(UIColor.tertiarySystemBackground)) // Background color
                //.foregroundColor(.blue) // Text color
                .accentColor(.blue) // Cursor color
                .cornerRadius(12)
        }
}
#Preview {
    TestView()
}
