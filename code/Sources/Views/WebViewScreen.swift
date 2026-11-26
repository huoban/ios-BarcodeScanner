import SwiftUI
import WebKit

struct WebViewScreen: View {
    let url: URL

    @State private var webView = WKWebView(frame: .zero)
    @State private var canGoBack = false

    var body: some View {
        WebViewContainer(webView: webView, url: url, canGoBack: $canGoBack)
            .navigationTitle("提交")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("后退") {
                        if self.canGoBack { self.webView.goBack() }
                    }
                    .disabled(!canGoBack)
                }
            }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    let url: URL
    @Binding var canGoBack: Bool

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.configuration.preferences.javaScriptEnabled = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.canGoBack = webView.canGoBack }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.canGoBack = webView.canGoBack }
        }
    }
}
