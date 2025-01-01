import SwiftUI
import UIKit
import SwiftMath

struct MathView: UIViewRepresentable {
    var equation: String
    var font: MathFont = .kpMathSansFont
    var textAlignment: MTTextAlignment = .left
    var fontSize: CGFloat = 16
    var labelMode: MTMathUILabelMode = .text
    var insets: MTEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    @Environment(\.colorScheme) var colorScheme

    
    func makeUIView(context: Context) -> MTMathUILabel {
        let view = MTMathUILabel()
        view.font = MTFontManager().font(withName: font.rawValue, size: fontSize)
        view.textAlignment = textAlignment
        view.labelMode = labelMode
        updateTextColor(view: view)
        //view.contentInsets = insets
        return view
    }
    func updateUIView(_ view: MTMathUILabel, context: Context) {
        view.latex = equation
        view.font = MTFontManager().font(withName: font.rawValue, size: fontSize)
        view.textAlignment = textAlignment
        view.labelMode = labelMode
        updateTextColor(view: view)
        //view.contentInsets = insets
    }
    
    private func updateTextColor(view: MTMathUILabel) {
        if colorScheme == .dark {
            view.textColor = MTColor(.white)
        } else {
            view.textColor = MTColor(.black)
        }
    }
    
}

// MARK: - FormattedTextView
struct FormattedTextView: View {
    let message: String

    var body: some View {
        let lines = preprocessMessage(message)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    view(for: line)
                }
            }
            .padding()
        }
    }
}

struct FormattedTextViewHelper: View {
    let text: String

    var body: some View {
        let components = parseInlineLaTeX(in: text)
        LazyVStack(alignment: .leading, spacing: 0) { // Replaced VStack with LazyVStack
            ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                switch component {
                case .text(let content):
                    // Process text with markdown rendering
                    if let attributedString = try? AttributedString(markdown: content) {
                        Text(attributedString)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(alignment: .leading)
                    } else {
                        Text(content)
                    }
                case .inlineLaTeX(let latex):
                    // Render inline LaTeX
                    MathView(equation: latex, fontSize: 16)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.80, alignment: .leading)
                }
            }
        }
    }
}

func view(for line: MarkdownLine, index: Int = 0) -> AnyView {
    switch line {
    case .numberedListItem(let number, let components):
        return AnyView(
            HStack(alignment: .top) {
                Text("\(number).") // Display the number
                    .font(.body)
                    .bold()
                    .frame(width: 30, alignment: .trailing)
                VStack(alignment: .leading, spacing: 4) {
                    renderComponents(components)
                }
            }
        )

    case .listItem(let components):
        return AnyView(
            HStack(alignment: .top) {
                Text("•")
                    .font(.body)
                    .bold()
                VStack(alignment: .leading, spacing: 4) {
                    renderComponents(components)
                }
            }
        )

    case .paragraph(let text):
        return AnyView(
            Text(attributedText(from: text))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        )

    case .codeBlock(let code):
        return AnyView(
            CodeBlockView(text: code)
        )

    case .displayLaTeX(let latex):
        return AnyView(
            MathView(equation: latex, fontSize: 16)
        )

    default:
        return AnyView(EmptyView())
    }
}

@ViewBuilder
func renderComponents(_ components: [InlineComponent]) -> some View {
    ForEach(Array(components.enumerated()), id: \.offset) { _, component in
        switch component {
        case .text(let content):
            Text(attributedText(from: content))
                .fixedSize(horizontal: false, vertical: true)
        case .inlineLaTeX(let latex):
            MathView(equation: latex, fontSize: 16)
                .padding(.vertical, 5)
        }
    }
}

func attributedText(from content: String) -> AttributedString {
    if let attributedString = try? AttributedString(markdown: content) {
        return attributedString
    } else {
        return AttributedString(content)
    }
}

// MARK: - HeadingView

struct HeadingView: View {
    let text: String
    let level: Int

    var body: some View {
        Text(text)
            .font(fontForLevel(level))
            .bold()
            .padding(.vertical, verticalPaddingForLevel(level))
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1:
            return .title
        case 2:
            return .title2
        case 3:
            return .title3
        case 4:
            return .headline
        default:
            return .body
        }
    }

    private func verticalPaddingForLevel(_ level: Int) -> CGFloat {
        switch level {
        case 1:
            return 8
        case 2:
            return 6
        case 3:
            return 4
        case 4:
            return 2
        default:
            return 2
        }
    }
}

// MARK: - ListItemView

struct ListItemView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text("•")
                .font(.body)
            ParagraphView(text: text)
        }
        .padding(.leading, 10)
    }
}

// MARK: - ParagraphView

struct ParagraphView: View {
    let text: String

    var body: some View {
        // Use AttributedString's markdown initializer for parsing
        if let attributedString = try? AttributedString(markdown: text) {
            Text(attributedString)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
        }
    }
}

// MARK: - CodeBlockView

struct CodeBlockView: View {
    let text: String
    @State private var isSheetPresented = false

    var body: some View {
        VStack {
            Button(action: {
                isSheetPresented.toggle()
            }) {
                Text("View Code Block")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .sheet(isPresented: $isSheetPresented) {
                CodeBlockSheet(text: text)
            }
        }
    }
}

struct CodeBlockSheet: View {
    let text: String

    var body: some View {
        NavigationView {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading) // Wraps text to fit the screen width
                    .onLongPressGesture(minimumDuration: 1.0) {
                        UIPasteboard.general.string = text
                        // Implement toast triggering here if needed
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = text
                            // Implement toast triggering here if needed
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
            }
            .padding()
            .navigationTitle("Code Block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

// MARK: - InlineCodeView

struct InlineCodeView: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.system(.body, design: .monospaced))
            .padding(4)
            .background(Color.gray)
            .cornerRadius(4)
    }
}

// MARK: - MarkdownLine Enum
enum MarkdownLine {
    case text(String)
    case inlineCode(String)
    case heading(String, Int)
    case listItem([InlineComponent])          // Bullet lists
    case numberedListItem(Int, [InlineComponent]) // Numbered lists
    case link(text: String, url: String)
    case codeBlock(String)
    case paragraph(String)
    case displayLaTeX(String)
    case inlineLaTeX(String)
}

func preprocessMessage(_ message: String) -> [MarkdownLine] {
    var result: [MarkdownLine] = []
    var inCodeBlock = false
    var codeBlockText = ""
    var inDisplayLaTeX = false
    var displayLaTeXText = ""
    
    // Regular expressions
    let linkPattern = #"$begin:math:display$([^$end:math:display$]+)\]$begin:math:text$([^)]+)$end:math:text$"#
    let numberedListPattern = #"^\d+\."# // Detect numbered list items
    //let latexPattern = #"\\$begin:math:display$(.*?)\\\\$end:math:display$"# // Display LaTeX blocks
    
    message.enumerateLines { line, _ in
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Handle Code Blocks
        if trimmedLine.hasPrefix("```") {
            inCodeBlock.toggle()
            if !inCodeBlock {
                result.append(.codeBlock(codeBlockText.trimmingCharacters(in: .whitespacesAndNewlines)))
                codeBlockText = ""
            }
            return
        }
        
        if inCodeBlock {
            codeBlockText += line + "\n"
            return
        }
        
        // Handle Display LaTeX Blocks
        if inDisplayLaTeX {
            if trimmedLine.hasSuffix("\\]") {
                let content = line.replacingOccurrences(of: "\\]", with: "")
                displayLaTeXText += content
                result.append(.displayLaTeX(displayLaTeXText.trimmingCharacters(in: .whitespacesAndNewlines)))
                displayLaTeXText = ""
                inDisplayLaTeX = false
            } else {
                displayLaTeXText += line + "\n"
            }
            return
        } else {
            if trimmedLine.hasPrefix("\\[") {
                let content = line.replacingOccurrences(of: "\\[", with: "")
                displayLaTeXText += content + "\n"
                inDisplayLaTeX = true
                return
            }
        }

        // Handle Numbered List Items
        if trimmedLine.range(of: numberedListPattern, options: .regularExpression) != nil {
            let parts = trimmedLine.split(separator: ".", maxSplits: 1)
            if let number = Int(parts[0]), parts.count > 1 {
                let content = parts[1].trimmingCharacters(in: .whitespaces)
                let components = parseInlineLaTeX(in: content)
                result.append(.numberedListItem(number, components))
                return
            }
        }

        // Handle Bullet List Items
        if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") {
            let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            let components = parseInlineLaTeX(in: content)
            result.append(.listItem(components))
            return
        }
        
        // Handle Inline LaTeX within the line
        let inlineComponents = parseInlineLaTeX(in: line)
        if inlineComponents.count > 1 {
            for component in inlineComponents {
                switch component {
                case .text(let content):
                    result.append(.text(content))
                case .inlineLaTeX(let latex):
                    result.append(.inlineLaTeX(latex))
                }
            }
        } else {
            // Handle other Markdown elements outside of code blocks
            if line.hasPrefix("#### ") {
                let headingText = line.replacingOccurrences(of: "#### ", with: "")
                result.append(.heading(headingText, 4))
            } else if line.hasPrefix("### ") {
                let headingText = line.replacingOccurrences(of: "### ", with: "")
                result.append(.heading(headingText, 3))
            } else if line.hasPrefix("## ") {
                let headingText = line.replacingOccurrences(of: "## ", with: "")
                result.append(.heading(headingText, 2))
            } else if line.hasPrefix("# ") {
                let headingText = line.replacingOccurrences(of: "# ", with: "")
                result.append(.heading(headingText, 1))
            } else if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: []),
                      let match = linkRegex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
                      match.numberOfRanges >= 3,
                      let linkTextRange = Range(match.range(at: 1), in: line),
                      let linkURLRange = Range(match.range(at: 2), in: line) {
                let linkText = String(line[linkTextRange])
                let url = String(line[linkURLRange])
                result.append(.link(text: linkText, url: url))
            } else {
                result.append(.paragraph(line))
            }
        }
    }
    
    // Handle any remaining unclosed code block
    if inCodeBlock && !codeBlockText.isEmpty {
        result.append(.codeBlock(codeBlockText.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
        
    // Handle any remaining unclosed Display LaTeX block
    if inDisplayLaTeX && !displayLaTeXText.isEmpty {
        result.append(.displayLaTeX(displayLaTeXText.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
    
    return result
}

// MARK: - Helper Function to Parse Inline LaTeX

enum InlineComponent {
    case text(String)
    case inlineLaTeX(String)
}

/// Parses a line to extract inline LaTeX expressions ($begin:math:text$...$end:math:text$).
/// Returns an array of InlineComponent representing the split parts.
func parseInlineLaTeX(in text: String) -> [InlineComponent] {
    var components: [InlineComponent] = []
    var remainingText = text
    while let startRange = remainingText.range(of: "\\(") {
        // Add text before the inline LaTeX
        if startRange.lowerBound > remainingText.startIndex {
            let textPart = String(remainingText[..<startRange.lowerBound])
            components.append(.text(textPart))
        }
        // Find the closing "\)"
        if let endRange = remainingText.range(of: "\\)", range: startRange.upperBound..<remainingText.endIndex) {
            let latexContent = String(remainingText[startRange.upperBound..<endRange.lowerBound])
            components.append(.inlineLaTeX(latexContent))
            // Update the remaining text
            remainingText = String(remainingText[endRange.upperBound...])
        } else {
            // No closing "\)", treat the rest as text
            let textPart = String(remainingText[startRange.lowerBound...])
            components.append(.text(textPart))
            break
        }
    }
    // Add any remaining text after the last LaTeX expression
    if !remainingText.isEmpty {
        components.append(.text(remainingText))
    }
    return components
}
