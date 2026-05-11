import SwiftUI
import WebKit

struct ArticleContentView: NSViewRepresentable {
    let html: String
    let onOpenInBrowser: (URL) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOpenInBrowser = onOpenInBrowser
        guard let templateURL = Bundle.main.url(forResource: "article-template", withExtension: "html"),
              let template = try? String(contentsOf: templateURL, encoding: .utf8) else {
            webView.loadHTMLString(html, baseURL: nil)
            return
        }
        let fullHTML = template.replacingOccurrences(of: "{{CONTENT}}", with: html)
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenInBrowser: onOpenInBrowser)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onOpenInBrowser: (URL) -> Void

        init(onOpenInBrowser: @escaping (URL) -> Void) {
            self.onOpenInBrowser = onOpenInBrowser
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                onOpenInBrowser(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
