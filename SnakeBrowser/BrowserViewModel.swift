import Foundation
import WebKit
import Combine

@MainActor
final class BrowserViewModel: ObservableObject {
    @Published var addressText = ""
    @Published var pageTitle = "Loris"
    @Published var isLoading = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var contentBlockingEnabled = true
    @Published var blockerReady = false
    @Published var blockerStatus = "Loading filters…"
    @Published private(set) var showingStartPage = true

    let webView: WKWebView
    let trafficLog: TrafficLogStore
    let adVault: AdVaultStore
    let interestPressure: InterestPressureStore
    let obfuscation: ObfuscationEngine

    private let contentBlocker = ContentBlocker()
    private let navigationDelegate = BrowserNavigationDelegate()
    private let matcher = AdFilterMatcher()
    private var trafficProbe: TrafficProbe!
    private var observations: [NSKeyValueObservation] = []

    init() {
        let trafficLog = TrafficLogStore()
        let adVault = AdVaultStore()
        let interestPressure = InterestPressureStore()
        self.trafficLog = trafficLog
        self.adVault = adVault
        self.interestPressure = interestPressure
        let obfuscation = ObfuscationEngine(vault: adVault, log: trafficLog, pressure: interestPressure)
        self.obfuscation = obfuscation

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        self.webView = webView

        let probe = TrafficProbe(
            matcher: matcher,
            logStore: trafficLog,
            blockingEnabled: { [weak self] in
                self?.contentBlockingEnabled ?? true
            },
            pageHost: { [weak self] in
                self?.webView.url?.host
            },
            pageURL: { [weak self] in
                self?.webView.url?.absoluteString
            },
            onAdCandidate: { [weak self] urlString, source, titleHint in
                self?.obfuscation.handleDetectedAdURL(
                    urlString,
                    pageHost: self?.webView.url?.host,
                    pageURL: self?.webView.url?.absoluteString,
                    source: source,
                    titleHint: titleHint
                )
            },
            onSubjectHint: { [weak self] text, url, source in
                self?.obfuscation.noteSubject(
                    text: text,
                    url: url,
                    pageHost: self?.webView.url?.host,
                    weight: 1.0,
                    source: source
                )
            }
        )
        probe.attach(to: webView.configuration.userContentController)
        MediaAutoUnmute.attach(to: webView.configuration.userContentController)
        self.trafficProbe = probe

        webView.navigationDelegate = navigationDelegate
        webView.uiDelegate = navigationDelegate
        navigationDelegate.onNavigate = { [weak self] url, source in
            Task { @MainActor in
                self?.trafficProbe.logNavigation(to: url, source: source)
            }
        }

        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.estimatedProgress = view.estimatedProgress
                }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.isLoading = view.isLoading
                }
            },
            webView.observe(\.title, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    let title = view.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    self?.pageTitle = title.isEmpty ? "Loris" : title
                }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if self.showingStartPage {
                        self.addressText = ""
                        return
                    }
                    if let url = view.url, Self.isBrowsableURL(url) {
                        self.addressText = url.absoluteString
                    }
                }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.canGoBack = view.canGoBack
                }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.canGoForward = view.canGoForward
                }
            }
        ]

        trafficLog.append(
            kind: .info,
            summary: "Monitor armed",
            detail: "Logging blocked ads/trackers and any real ad-click URL navigations.",
            dedupeWindow: false
        )

        Task {
            await prepareContentBlocking()
            loadStartPage()
            // Default Privacy Lab decoys on for the research experiment.
            obfuscation.setEnabled(true)
        }
    }

    deinit {
        observations.forEach { $0.invalidate() }
    }

    func loadStartPage() {
        showingStartPage = true
        addressText = ""
        pageTitle = "Loris"
        webView.stopLoading()
        webView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    func goHome() {
        loadStartPage()
    }

    /// Leave the home grid for a blank page and empty address bar (ready to type a URL).
    func beginBlankURLEntry() {
        showingStartPage = false
        addressText = ""
        pageTitle = "Loris"
        webView.stopLoading()
        webView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    func loadAddressBar() {
        guard let url = Self.sanitizedURL(from: addressText) else { return }
        showingStartPage = false
        addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func open(_ url: URL) {
        showingStartPage = false
        addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        if showingStartPage {
            loadStartPage()
        } else {
            webView.reload()
        }
    }

    func stop() {
        webView.stopLoading()
    }

    func setContentBlockingEnabled(_ enabled: Bool) {
        contentBlockingEnabled = enabled
        trafficLog.append(
            kind: .info,
            summary: enabled ? "Blocking ON" : "Blocking OFF",
            detail: enabled
                ? "Matching ad/tracker requests will be marked BLOCKED."
                : "Matching ad/tracker requests may appear as AD HIT / TRACKER.",
            dedupeWindow: false
        )
        Task {
            await applyContentBlocking()
            if !showingStartPage {
                webView.reload()
            }
        }
    }

    private func prepareContentBlocking() async {
        do {
            try await contentBlocker.prepare()
            blockerReady = true
            blockerStatus = "Filters ready"
            trafficLog.append(
                kind: .info,
                summary: "Filters ready",
                detail: "Content rules compiled and attached.",
                dedupeWindow: false
            )
            await applyContentBlocking()
        } catch {
            blockerReady = false
            blockerStatus = "Filters unavailable"
            trafficLog.append(
                kind: .info,
                summary: "Filters unavailable",
                detail: error.localizedDescription,
                dedupeWindow: false
            )
        }
    }

    private func applyContentBlocking() async {
        let rules = contentBlockingEnabled ? contentBlocker.compiledRules : nil
        await contentBlocker.apply(rules, to: webView)
    }

    static func isBrowsableURL(_ url: URL) -> Bool {
        let scheme = (url.scheme ?? "").lowercased()
        return scheme == "http" || scheme == "https"
    }

    static func sanitizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           (scheme == "http" || scheme == "https"), url.host != nil {
            return url
        }

        if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)")
        }

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        return components?.url
    }
}
