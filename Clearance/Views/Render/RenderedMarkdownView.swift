import SwiftUI
import WebKit

struct RenderedMarkdownView: NSViewRepresentable {
    let document: ParsedMarkdownDocument
    private let builder = RenderedHTMLBuilder()

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(builder.build(document: document), baseURL: Bundle.main.bundleURL)
    }
}
