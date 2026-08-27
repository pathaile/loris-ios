import Foundation

struct AdFilterMatcher {
    /// Domains we treat as blockable ads/trackers (not Meta app infrastructure).
    private let blockDomains: [String]
    private let trackerHints: [String]

    init() {
        var found = Set<String>()
        if let url = Bundle.main.url(forResource: "blockerList", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let rules = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for rule in rules {
                guard let trigger = rule["trigger"] as? [String: Any],
                      let filter = trigger["url-filter"] as? String else { continue }
                for piece in Self.extractDomains(from: filter) where !Self.isMetaInfrastructure(piece) {
                    found.insert(piece)
                }
            }
        }

        for domain in Self.baselineBlockDomains {
            found.insert(domain)
        }

        blockDomains = found.sorted()
        trackerHints = [
            "google-analytics", "googletagmanager", "scorecardresearch", "quantserve",
            "hotjar", "mixpanel", "segment.", "clarity.ms", "newrelic", "sentry",
            "pixel.", "/beacon", "/collect", "offsite_event", "impression",
            "/tr?", "facebook.com/tr"
        ]
    }

    func isMetaHost(_ host: String?) -> Bool {
        guard var host = host?.lowercased(), !host.isEmpty else { return false }
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        let roots = [
            "instagram.com", "facebook.com", "fbcdn.net", "cdninstagram.com",
            "meta.com", "fbsbx.com", "accountkit.com"
        ]
        return roots.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    /// Navigating away from Instagram/Facebook to some other site (typical ad landing).
    func isExternalLeave(from pageHost: String?, to url: URL) -> Bool {
        guard isMetaHost(pageHost) else { return false }
        guard let host = url.host else { return false }
        return !isMetaHost(host)
    }

    /// True outbound click/measurement redirects (user left toward an advertiser).
    func isOutboundClickURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else {
            return false
        }
        let path = url.path.lowercased()
        let absolute = urlString.lowercased()
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

        let shimHosts: Set<String> = [
            "l.instagram.com",
            "lm.facebook.com",
            "l.facebook.com"
        ]
        if shimHosts.contains(host) || shimHosts.contains(bare) {
            return true
        }

        // Instagram / Facebook paid-click redirect endpoints (still on Meta hosts).
        if bare == "facebook.com" || bare.hasSuffix(".facebook.com") {
            if path.contains("/ads/ig_redirect") ||
                path.contains("/ads/redirect") ||
                absolute.contains("ig_redirect") ||
                absolute.contains("offsite_event") ||
                path.contains("/n/") && absolute.contains("ad") {
                return true
            }
        }

        // Instagram sometimes uses path-based exits.
        if bare == "instagram.com" && (path.hasPrefix("/l/") || absolute.contains("linkshim") || absolute.contains("ig_redirect")) {
            return true
        }

        if absolute.contains("doubleclick.net/aclk") { return true }
        if absolute.contains("googleadservices.com/pagead/aclk") { return true }
        if absolute.contains("/aclk?") || path.hasSuffix("/aclk") { return true }
        if absolute.contains("adnxs.com/click") { return true }
        if absolute.contains("outbrain.com/network/redir") { return true }
        if absolute.contains("taboola.com/action") { return true }

        return false
    }

    func classify(urlString: String, blockingEnabled: Bool) -> TrafficKind? {
        let lower = urlString.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return nil }

        if isOutboundClickURL(lower) {
            return .adClick
        }

        let matchedDomain = matchingDomain(in: lower)
        let looksTracker = trackerHints.contains { lower.contains($0) }

        if let matchedDomain {
            if looksTracker {
                return blockingEnabled ? .blocked : .tracker
            }
            if blockingEnabled {
                return .blocked
            }
            return .adRequest
        }

        if looksTracker {
            return blockingEnabled ? .blocked : .tracker
        }

        return nil
    }

    func matchingDomain(in urlString: String) -> String? {
        let lower = urlString.lowercased()
        return blockDomains.first { domain in
            lower.contains(domain)
        }
    }

    private static func isMetaInfrastructure(_ domain: String) -> Bool {
        let d = domain.lowercased()
        return d.contains("facebook") || d.contains("instagram") || d.contains("fbcdn") || d.contains("meta.com") || d.contains("fbsbx")
    }

    private static func extractDomains(from filter: String) -> [String] {
        let cleaned = filter
            .replacingOccurrences(of: #"\\."#, with: ".", options: .regularExpression)
            .replacingOccurrences(of: #"\^"#, with: "")
            .replacingOccurrences(of: #"[()[\]?+*]"#, with: "", options: .regularExpression)

        var results: [String] = []
        let pattern = #"[a-z0-9-]+(?:\.[a-z0-9-]+)+"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            regex.enumerateMatches(in: cleaned, range: range) { match, _, _ in
                guard let match, let swiftRange = Range(match.range, in: cleaned) else { return }
                let value = String(cleaned[swiftRange]).lowercased()
                if value.contains(".") && !value.hasPrefix("www.") {
                    results.append(value)
                }
            }
        }
        return results
    }

    private static let baselineBlockDomains = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com",
        "googletagmanager.com", "google-analytics.com", "adservice.google.com",
        "amazon-adsystem.com", "adnxs.com", "adsrvr.org", "criteo.com", "criteo.net",
        "taboola.com", "outbrain.com", "scorecardresearch.com", "quantserve.com",
        "moatads.com", "pubmatic.com", "rubiconproject.com", "openx.net",
        "ads-twitter.com", "bat.bing.com", "ads.linkedin.com",
        "hotjar.com", "mixpanel.com", "clarity.ms"
    ]
}
