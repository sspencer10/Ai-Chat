import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let htmlContent: String
    let onLoadFinished: (() -> Void)?
    let onLoadError: ((Error?) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.navigationDelegate = context.coordinator
        print("WebView makeUIView called")
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("WebView updateUIView called with HTML content")
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadFinished: onLoadFinished, onLoadError: onLoadError)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onLoadFinished: (() -> Void)?
        let onLoadError: ((Error?) -> Void)?
        
        init(onLoadFinished: (() -> Void)?, onLoadError: ((Error?) -> Void)?) {
            self.onLoadFinished = onLoadFinished
            self.onLoadError = onLoadError
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading.")
            onLoadFinished?()
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed to load: \(error.localizedDescription)")
            onLoadError?(error)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView failed provisional navigation: \(error.localizedDescription)")
            onLoadError?(error)
        }
    }
}
