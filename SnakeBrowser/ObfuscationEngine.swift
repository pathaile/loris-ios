import Foundation
import WebKit
import Combine

/// Background privacy/obfuscation worker.
/// Visible browsing stays in the main WKWebView; decoy loads use a separate hidden WKWebView.
/// Never automates paid-ad click/redirect URLs.
@MainActor
final class ObfuscationEngine: NSObject, ObservableObject {
    @Published var isEnabled = false
    @Published var reactToDetectedAds = true
    @Published var intervalSeconds: Double = 120
    @Published var lastStatus = "Idle"
    @Published var decoyCount = 0
    @Published var skippedBillableCount = 0
    @Published var vaultedCount = 0

    private let vault: AdVaultStore
    private let log: TrafficLogStore
    private let pressure: InterestPressureStore
    private let catalog: DecoyCatalog
    private let decoyWebView: WKWebView
    private var timer: Timer?
    private var lastDecoyAt: Date = .distantPast
    private var lastLoggedSubjectID: String?
    private let minGapBetweenDecoys: TimeInterval = 45

    init(vault: AdVaultStore, log: TrafficLogStore, pressure: InterestPressureStore) {
        self.vault = vault
        self.log = log
        self.pressure = pressure
        self.catalog = DecoyCatalog.loadFromBundle()

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        self.decoyWebView = webView

        super.init()
        webView.navigationDelegate = self
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        timer?.invalidate()
        timer = nil

        if enabled {
            lastStatus = "Obfuscation on — scheduling benign decoy navigations"
            log.append(
                kind: .info,
                summary: "Obfuscation ON",
                detail: "Decoy browsing enabled. Paid-ad click URLs will be vaulted/skipped, never auto-visited.",
                dedupeWindow: false
            )
            scheduleTimer()
            Task { await runDecoyCycle(reason: "enable") }
        } else {
            lastStatus = "Obfuscation off"
            log.append(
                kind: .info,
                summary: "Obfuscation OFF",
                detail: "Decoy browsing paused.",
                dedupeWindow: false
            )
        }
    }

    func handleDetectedAdURL(
        _ urlString: String,
        pageHost: String?,
        pageURL: String?,
        source: String,
        titleHint: String? = nil
    ) {
        guard let result = vault.record(
            targetURL: urlString,
            pageHost: pageHost,
            pageURL: pageURL,
            source: source,
            titleHint: titleHint
        ) else { return }

        let ad = result.ad
        vaultedCount = vault.ads.count

        // Only log vault/skip once per newly vaulted creative (avoid SKIPPED spam).
        guard result.isNew else {
            // Still refresh subject pressure on repeats with lighter weight.
            noteSubject(text: titleHint, url: urlString, pageHost: pageHost, weight: 0.25, source: source)
            return
        }

        log.append(
            kind: .vault,
            summary: ad.targetHost ?? "ad",
            detail: "Vaulted · \(source) · \(ad.targetURL)",
            pageHost: pageHost,
            dedupeWindow: false
        )

        noteSubject(text: titleHint, url: urlString, pageHost: pageHost, weight: 1.5, source: source)

        if ad.isBillableClickURL {
            skippedBillableCount += 1
            log.append(
                kind: .skipped,
                summary: ad.targetHost ?? "billable-url",
                detail: PaidClickPolicy.skipReason + " · \(ad.targetURL)",
                pageHost: pageHost,
                dedupeWindow: false
            )
        }

        guard isEnabled, reactToDetectedAds else { return }

        // Research-safe response: decoy category page, never the paid click URL.
        Task {
            await runDecoyCycle(reason: "ad-detected")
        }
    }

    func noteSubject(text: String?, url: String?, pageHost: String?, weight: Double, source: String) {
        guard let subject = pressure.observe(text: text, url: url, pageHost: pageHost, weight: weight) else {
            return
        }
        let changed = lastLoggedSubjectID != subject
        lastLoggedSubjectID = subject
        // Keep pressure scores warm on repeats; only emit SUBJECT lines on change or strong signals.
        guard changed || weight >= 1.0 else { return }

        let label = InterestPressureStore.label(for: subject)
        let sample = text ?? url ?? pageHost ?? "signal"
        log.append(
            kind: .subject,
            summary: label,
            detail: "\(source) · inferred from \(sample.prefix(120))",
            pageHost: pageHost,
            dedupeWindow: true
        )
    }

    func runDecoyNow() {
        Task { await runDecoyCycle(reason: "manual") }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.runDecoyCycle(reason: "timer")
            }
        }
    }

    private func runDecoyCycle(reason: String) async {
        guard isEnabled || reason == "manual" else { return }
        let now = Date()
        if reason != "manual", now.timeIntervalSince(lastDecoyAt) < minGapBetweenDecoys {
            return
        }

        let counters = pressure.counterDecoyCategoryIDs()
        guard let pick = catalog.randomTarget(preferringCategoryIDs: counters) else {
            lastStatus = "No decoy URLs available"
            return
        }

        let against = pressure.dominant.map { "against \($0.label)" } ?? "no dominant pressure"
        lastDecoyAt = now
        decoyCount += 1
        lastStatus = "Decoy → \(pick.category.label) (\(against))"
        log.append(
            kind: .decoy,
            summary: pick.category.label,
            detail: "\(reason) · \(against) · loaded \(pick.url.absoluteString) in background (not a paid-click URL)",
            pageHost: pick.url.host,
            dedupeWindow: false
        )
        decoyWebView.load(URLRequest(url: pick.url))
    }
}

extension ObfuscationEngine: WKNavigationDelegate {
    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let absolute = url.absoluteString
        if PaidClickPolicy.isLikelyBillableClickURL(absolute) {
            Task { @MainActor in
                self.skippedBillableCount += 1
                self.log.append(
                    kind: .skipped,
                    summary: url.host ?? "blocked-nav",
                    detail: "Background decoy blocked billable URL · \(absolute)",
                    dedupeWindow: false
                )
            }
            decisionHandler(.cancel)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()
        decisionHandler((scheme == "http" || scheme == "https" || scheme == "about") ? .allow : .cancel)
    }
}
