import Foundation
import SwiftUI
import CoreData
import AVFoundation
import Photos

// MARK: - FormattedTextView

struct FormattedTextView: View {
    let message: String

    var body: some View {
        let lines = preprocessMessage(message)

        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    switch line {
                    case .heading(let text, let level):
                        HeadingView(text: text, level: level)
                    case .listItem(let text):
                        ListItemView(text: text)
                    case .codeBlock(let code):
                        CodeBlockView(text: code)
                    case .paragraph(let text):
                        Text.formattedText(from: text)
                    case .text(let content):
                        Text(content)
                    case .inlineCode(let code):
                        InlineCodeView(code: code)
                    case .link(let text, let url):
                        if let url = URL(string: url) {
                            Link(text, destination: url)
                                .foregroundColor(.blue)
                        } else {
                            Text(text)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - HeadingView

struct HeadingView: View {
    let text: String
    let level: Int

    var body: some View {
        switch level {
        case 1:
            Text(text)
                .font(.title)
                .bold()
                .padding(.vertical, 8)
        case 2:
            Text(text)
                .font(.title2)
                .bold()
                .padding(.vertical, 6)
        case 3:
            Text(text)
                .font(.title3)
                .bold()
                .padding(.vertical, 4)
        case 4:
            Text(text)
                .font(.headline)
                .bold()
                .padding(.vertical, 2)
        default:
            Text(text)
                .font(.body)
                .bold()
        }
    }
}

// MARK: - ListItemView

struct ListItemView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top) {
            Text("• ")
                .font(.body)
            Text.formattedText(from: text)
        }
        .padding(.leading, 10)
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
    @StateObject var contentClass = ContentClass()
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
                        contentClass.triggerToast()
                    }
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = text
                            contentClass.triggerToast()
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
            .background(Color.gray.opacity(0.2))
            .cornerRadius(4)
    }
}

// MARK: - Text Extension for Formatted Text

extension Text {
    static func formattedText(from message: String) -> Text {
        var formattedText = Text("")
        var currentIndex = message.startIndex

        // Corrected pattern to capture inline code, bold, italic without overlapping
        let combinedPattern = #"(`[^`]+`)|(\*\*[^*]+\*\*)|(_[^_]+_)"#
        guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: []) else {
            return Text(message)
        }

        let nsMessage = message as NSString
        let matches = regex.matches(in: message, range: NSRange(location: 0, length: nsMessage.length))

        for match in matches {
            guard let range = Range(match.range, in: message) else { continue }

            // Add plain text before the match
            if currentIndex < range.lowerBound {
                let plainText = String(message[currentIndex..<range.lowerBound])
                formattedText = formattedText + Text(plainText)
            }

            let matchedText = String(message[range])

            if matchedText.hasPrefix("**"), matchedText.hasSuffix("**") {
                let boldText = matchedText.dropFirst(2).dropLast(2)
                formattedText = formattedText + Text(String(boldText)).bold()
            } else if matchedText.hasPrefix("_"), matchedText.hasSuffix("_") {
                let italicText = matchedText.dropFirst().dropLast()
                formattedText = formattedText + Text(String(italicText)).italic()
            } else if matchedText.hasPrefix("`"), matchedText.hasSuffix("`") {
                let codeText = matchedText.dropFirst().dropLast()
                formattedText = formattedText + Text(String(codeText))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
            }

            currentIndex = range.upperBound
        }

        // Add any remaining plain text after the last match
        if currentIndex < message.endIndex {
            let remainingText = String(message[currentIndex..<message.endIndex])
            formattedText = formattedText + Text(remainingText)
        }

        return formattedText
    }
}

// MARK: - MarkdownLine Enum

enum MarkdownLine {
    case text(String)
    case inlineCode(String)
    case heading(String, Int)
    case listItem(String)
    case codeBlock(String)
    case paragraph(String)
    case link(text: String, url: String)
}

func preprocessMessage(_ message: String) -> [MarkdownLine] {
    var result: [MarkdownLine] = []
    var inCodeBlock: Bool = false
    var codeBlockText = ""

    message.enumerateLines { line, _ in
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            if inCodeBlock {
                // Close the current code block
                result.append(.codeBlock(codeBlockText.trimmingCharacters(in: .whitespacesAndNewlines)))
                codeBlockText = ""
                inCodeBlock = false
            } else {
                // Open a new code block
                inCodeBlock = true
            }
        } else if inCodeBlock {
            // Accumulate lines inside a code block
            codeBlockText += line + "\n"
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
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let listItemText = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                result.append(.listItem(String(listItemText)))
            } else if line.contains("[") && line.contains(")") {
                let linkPattern = #"$begin:math:display$([^$end:math:display$]+)\]$begin:math:text$([^)]+)$end:math:text$"#
                if let linkRegex = try? NSRegularExpression(pattern: linkPattern),
                   let match = linkRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)),
                   let linkTextRange = Range(match.range(at: 1), in: line),
                   let linkURLRange = Range(match.range(at: 2), in: line) {
                    let linkText = String(line[linkTextRange])
                    let url = String(line[linkURLRange])
                    result.append(.link(text: linkText, url: url))
                } else {
                    result.append(.paragraph(line))
                }
            } else {
                result.append(.paragraph(line))
            }
        }
    }

    // Handle any remaining unclosed code block
    if inCodeBlock && !codeBlockText.isEmpty {
        result.append(.codeBlock(codeBlockText.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    return result
}
