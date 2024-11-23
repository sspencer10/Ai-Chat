import Foundation
import WebKit
import PDFKit
import UIKit

class PDFGenerator: NSObject, WKNavigationDelegate {
    private var webView: WKWebView!
    private var completion: (URL?) -> Void

    // Updated initializer: Initialize 'completion' before calling 'super.init()'
    init(htmlContent: String, completion: @escaping (URL?) -> Void) {
        self.completion = completion // Initialize stored property first
        super.init() // Then call the superclass initializer
        
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792), configuration: config) // A4 size
        self.webView.navigationDelegate = self
        self.webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    // WKNavigationDelegate method
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WKWebView finished loading.")
        generatePDF(from: webView)
    }

    private func generatePDF(from webView: WKWebView) {
        webView.createPDF { result in
            switch result {
            case .success(let data):
                let tempDirectory = FileManager.default.temporaryDirectory
                let fileName = "ChatSession_\(UUID().uuidString).pdf"
                let pdfURL = tempDirectory.appendingPathComponent(fileName)
                
                do {
                    try data.write(to: pdfURL)
                    print("PDF Generated at: \(pdfURL)")
                    
                    // Schedule deletion after sharing (e.g., 60 seconds)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                        do {
                            try FileManager.default.removeItem(at: pdfURL)
                            print("Temporary PDF file deleted: \(pdfURL)")
                        } catch {
                            print("Failed to delete temporary PDF file: \(error.localizedDescription)")
                        }
                    }
                    
                    // Return the PDF URL via the completion handler
                    self.completion(pdfURL)
                } catch {
                    print("Failed to write PDF file: \(error.localizedDescription)")
                    self.completion(nil)
                }
                
            case .failure(let error):
                print("Failed to create PDF: \(error.localizedDescription)")
                self.completion(nil)
            }
        }
    }
}
