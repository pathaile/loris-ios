import Foundation
import WebKit

/// Not MainActor-isolated: WebKit expects `decisionHandler` to be called promptly
/// on its callback thread. Logging hops to the main actor separately.
final class BrowserNavigationDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    var onNavigate: ((URL, String) -> Void)?

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let scheme = (url.scheme ?? "").lowercased()
        let frame: String = {
            if navigationAction.targetFrame == nil { return "popup" }
            return navigationAction.targetFrame?.isMainFrame == true ? "main" : "iframe"
        }()
        let navType = String(describing: navigationAction.navigationType.rawValue)

        switch scheme {
        case "http", "https":
            onNavigate?(url, "nav:\(frame):\(navType)")
            decisionHandler(.allow)
        case "about", "blob", "data", "file":
            decisionHandler(.allow)
        default:
            // Never hand off to Safari / other apps.
            onNavigate?(url, "blocked-scheme:\(scheme)")
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
        if let url = webView.url {
            onNavigate?(url, "provisional")
        }
    }

    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        if let url = webView.url {
            onNavigate?(url, "redirect")
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Keep window.open / target=_blank inside Loris (prevents Safari handoff).
        if let url = navigationAction.request.url {
            onNavigate?(url, "window.open")
            let scheme = (url.scheme ?? "").lowercased()
            if scheme == "http" || scheme == "https" {
                webView.load(URLRequest(url: url))
            }
        } else if let url = navigationAction.request.mainDocumentURL {
            onNavigate?(url, "window.open-doc")
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    // Refuse to open system preview / external commit paths when possible.
    @available(iOS 15.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.deny)
    }
}
