import Foundation

/// Policy for avoiding automated hits on endpoints that may create paid-ad accounting.
/// Inspired by AdNauseam's separation of detection vs visitation, but deliberately
/// refuses billable click/redirect automation for this personal research build.
enum PaidClickPolicy {
    static func isLikelyBillableClickURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else {
            return false
        }
        let path = url.path.lowercased()
        let absolute = urlString.lowercased()
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

        if ["l.instagram.com", "lm.facebook.com", "l.facebook.com"].contains(bare) {
            return true
        }
        if bare.hasSuffix("facebook.com") || bare == "facebook.com" {
            if path.contains("/ads/ig_redirect") ||
                path.contains("/ads/redirect") ||
                absolute.contains("ig_redirect") ||
                absolute.contains("offsite_event") {
                return true
            }
        }
        if bare == "instagram.com" && (path.hasPrefix("/l/") || absolute.contains("linkshim")) {
            return true
        }
        if absolute.contains("/aclk") || absolute.contains("pagead/aclk") { return true }
        if absolute.contains("doubleclick.net") && (absolute.contains("aclk") || absolute.contains("click")) {
            return true
        }
        if absolute.contains("googleadservices.com") && absolute.contains("aclk") { return true }
        if absolute.contains("adnxs.com/click") { return true }
        if absolute.contains("outbrain.com/network/redir") { return true }
        if absolute.contains("taboola.com/action") { return true }
        if absolute.contains("clickserve") || absolute.contains("adsclick") { return true }

        return false
    }

    static func isSafePublicNavigationURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return false }
        return !isLikelyBillableClickURL(urlString)
    }

    static var skipReason: String {
        "Skipped automated visit: URL looks like a paid-ad click/redirect endpoint (may create billing or attribution events)."
    }
}
