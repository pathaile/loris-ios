import Foundation
import WebKit

final class TrafficProbe: NSObject, WKScriptMessageHandler {
    static let messageName = "snakeTraffic"

    private let matcher: AdFilterMatcher
    private weak var logStore: TrafficLogStore?
    private var blockingEnabled: () -> Bool
    private var pageHost: () -> String?
    private var pageURL: () -> String?
    private var onAdCandidate: ((String, String, String?) -> Void)?
    private var onSubjectHint: ((String?, String?, String) -> Void)?

    init(
        matcher: AdFilterMatcher,
        logStore: TrafficLogStore,
        blockingEnabled: @escaping () -> Bool,
        pageHost: @escaping () -> String?,
        pageURL: @escaping () -> String? = { nil },
        onAdCandidate: ((String, String, String?) -> Void)? = nil,
        onSubjectHint: ((String?, String?, String) -> Void)? = nil
    ) {
        self.matcher = matcher
        self.logStore = logStore
        self.blockingEnabled = blockingEnabled
        self.pageHost = pageHost
        self.pageURL = pageURL
        self.onAdCandidate = onAdCandidate
        self.onSubjectHint = onSubjectHint
    }

    func attach(to controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: Self.messageName)
        controller.add(self, name: Self.messageName)
        controller.addUserScript(Self.probeScript(worldName: "page", world: .page))
        controller.addUserScript(Self.probeScript(worldName: "client", world: .defaultClient))
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageName,
              let body = message.body as? [String: Any] else { return }

        let source = (body["source"] as? String) ?? "probe"
        let urlString = body["url"] as? String
        let text = body["text"] as? String
        let eventKind = body["kind"] as? String

        Task { @MainActor in
            if eventKind == "ad-subject" {
                self.onSubjectHint?(text, urlString, source)
                return
            }

            if eventKind == "tap" || source.hasPrefix("tap") {
                self.logTap(urlString: urlString, text: text, source: source)
                if let urlString {
                    // Meta ad redirects on a sponsored tap count as EXIT CLICK too.
                    if self.matcher.isOutboundClickURL(urlString) {
                        self.logStore?.append(
                            kind: .adClick,
                            summary: URL(string: urlString)?.host ?? "ig-redirect",
                            detail: "\(source) · \(urlString)",
                            pageHost: self.pageHost(),
                            dedupeWindow: true
                        )
                        self.emitAdCandidate(urlString, source: source, titleHint: text)
                    } else {
                        self.handleObservedURL(urlString, source: source)
                    }
                } else if let text {
                    self.onSubjectHint?(text, self.pageURL(), source)
                }
                return
            }

            guard let urlString else { return }
            self.handleObservedURL(urlString, source: source)
        }
    }

    @MainActor
    private func emitAdCandidate(_ urlString: String, source: String, titleHint: String? = nil) {
        if matcher.isOutboundClickURL(urlString)
            || PaidClickPolicy.isLikelyBillableClickURL(urlString)
            || matcher.classify(urlString: urlString, blockingEnabled: blockingEnabled()) != nil {
            onAdCandidate?(urlString, source, titleHint)
        }
    }

    @MainActor
    private func logTap(urlString: String?, text: String?, source: String) {
        let summary: String
        if let urlString, let host = URL(string: urlString)?.host {
            summary = host
        } else if let text, !text.isEmpty {
            summary = String(text.prefix(48))
        } else {
            summary = "on-page tap"
        }

        var detailParts = [source]
        if let text, !text.isEmpty {
            detailParts.append("text=\(text.prefix(80))")
        }
        if let urlString {
            detailParts.append(urlString)
        }

        logStore?.append(
            kind: .tap,
            summary: summary,
            detail: detailParts.joined(separator: " · "),
            pageHost: pageHost(),
            dedupeWindow: true
        )
    }

    @MainActor
    func handleObservedURL(_ urlString: String, source: String) {
        let blocking = blockingEnabled()
        let currentPage = pageHost()
        let userDriven = Self.isUserDrivenSource(source)

        if let url = URL(string: urlString), matcher.isExternalLeave(from: currentPage, to: url) {
            logStore?.append(
                kind: userDriven ? .adClick : .adRequest,
                summary: url.host ?? "external",
                detail: "\(source) · left Meta → \(urlString)",
                pageHost: currentPage
            )
            return
        }

        if matcher.isOutboundClickURL(urlString) {
            // DOM/perf discovery of ig_redirect links ≠ a click. Only user-driven counts as EXIT.
            logStore?.append(
                kind: userDriven ? .adClick : .adRequest,
                summary: URL(string: urlString)?.host ?? "ig-redirect",
                detail: "\(source) · \(urlString)",
                pageHost: currentPage
            )
            emitAdCandidate(urlString, source: source)
            return
        }

        guard var kind = matcher.classify(urlString: urlString, blockingEnabled: blocking) else {
            return
        }

        if kind == .adClick && !userDriven {
            kind = .adRequest
        }

        let host = URL(string: urlString)?.host ?? urlString
        let matched = matcher.matchingDomain(in: urlString) ?? host

        logStore?.append(
            kind: kind,
            summary: kind == .adClick ? "Exit click" : matched,
            detail: "\(source) · \(urlString)",
            pageHost: currentPage
        )
        emitAdCandidate(urlString, source: source)
    }

    private static func isUserDrivenSource(_ source: String) -> Bool {
        source.hasPrefix("tap") ||
        source.hasPrefix("click") ||
        source.hasPrefix("window.open") ||
        source.contains("nav:main") ||
        source.contains("nav:popup") ||
        source.contains("redirect")
    }

    @MainActor
    func logNavigation(to url: URL, source: String) {
        let urlString = url.absoluteString
        let scheme = (url.scheme ?? "").lowercased()
        let currentPage = pageHost()

        if scheme != "http" && scheme != "https" {
            // Ignore our local start page noise.
            if scheme == "file" { return }
            logStore?.append(
                kind: .info,
                summary: "Blocked leave-app URL",
                detail: "\(source) · \(urlString)",
                pageHost: currentPage,
                dedupeWindow: true
            )
            return
        }

        if matcher.isOutboundClickURL(urlString) || matcher.isExternalLeave(from: currentPage, to: url) {
            let userDriven = Self.isUserDrivenSource(source)
            logStore?.append(
                kind: userDriven ? .adClick : .adRequest,
                summary: url.host ?? "exit",
                detail: "\(source) · \(urlString)",
                pageHost: currentPage,
                dedupeWindow: true
            )
            emitAdCandidate(urlString, source: source)
            return
        }

        if let kind = matcher.classify(urlString: urlString, blockingEnabled: blockingEnabled()),
           kind != .page {
            handleObservedURL(urlString, source: source)
            return
        }

        if let host = url.host {
            let isAdRedirect = matcher.isOutboundClickURL(urlString)
            let isMainish = Self.isUserDrivenSource(source) || source.contains("provisional") || source.contains("nav:iframe")
            if isAdRedirect {
                logStore?.append(
                    kind: Self.isUserDrivenSource(source) ? .adClick : .adRequest,
                    summary: host,
                    detail: "\(source) · \(urlString)",
                    pageHost: currentPage,
                    dedupeWindow: true
                )
                return
            }
            if isMainish || !matcher.isMetaHost(host) {
                logStore?.append(
                    kind: .page,
                    summary: host,
                    detail: "\(source) · \(urlString)",
                    pageHost: currentPage ?? host,
                    dedupeWindow: true
                )
            }
        }
    }

    private static func probeScript(worldName: String, world: WKContentWorld) -> WKUserScript {
        let source = """
        (function() {
          const flag = '__snakeTrafficInstalled_\(worldName)';
          if (window[flag]) { return; }
          window[flag] = true;

          const post = (payload) => {
            try {
              window.webkit.messageHandlers.\(TrafficProbe.messageName).postMessage(payload);
            } catch (e) {}
          };

          const absoluteURL = (url) => {
            try { return new URL(url, document.baseURI).href; } catch (e) { return url; }
          };

          const postURL = (url, source) => {
            if (!url || typeof url !== 'string') return;
            const absolute = absoluteURL(url);
            if (!(absolute.startsWith('http://') || absolute.startsWith('https://'))) return;
            post({url: absolute, source: source});
          };

          const wrap = (obj, method, source) => {
            try {
              const original = obj[method];
              if (typeof original !== 'function') return;
              obj[method] = function() {
                try {
                  if (arguments.length > 0) postURL(String(arguments[0]), source);
                } catch (e) {}
                return original.apply(this, arguments);
              };
            } catch (e) {}
          };

          wrap(window, 'open', 'window.open');
          wrap(window, 'fetch', 'fetch');
          if (window.XMLHttpRequest && XMLHttpRequest.prototype) {
            const open = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function() {
              try {
                if (arguments.length > 1) postURL(String(arguments[1]), 'xhr');
              } catch (e) {}
              return open.apply(this, arguments);
            };
          }

          const isMetaHost = (host) => {
            if (!host) return false;
            host = String(host).toLowerCase().replace(/^www\\./, '');
            return /(^|\\.)instagram\\.com$|(^|\\.)facebook\\.com$|(^|\\.)fbcdn\\.net$|(^|\\.)cdninstagram\\.com$|(^|\\.)meta\\.com$/.test(host);
          };

          const scanNode = (node, source) => {
            if (!node || node.nodeType !== 1) return;
            ['src', 'href', 'data-src', 'data-url', 'data-href'].forEach((attr) => {
              const value = node.getAttribute && node.getAttribute(attr);
              if (value) postURL(value, source + ':' + (node.tagName || 'node').toLowerCase());
            });
            if (node.querySelectorAll) {
              node.querySelectorAll('[src],[href],[data-src],[data-url],[data-href]').forEach((el) => scanNode(el, source));
            }
          };

          let lastAdSubject = '';
          const postSubject = (text, source) => {
            try {
              const cleaned = String(text || '').replace(/\\s+/g, ' ').trim();
              if (!cleaned || cleaned.length < 3) return;
              if (cleaned === lastAdSubject) return;
              lastAdSubject = cleaned;
              post({
                kind: 'ad-subject',
                source: source,
                text: cleaned.slice(0, 180),
                url: location.href
              });
            } catch (e) {}
          };

          const scrapeVideoAdSubject = () => {
            try {
              const host = String(location.hostname || '').toLowerCase();
              const videoHost = /(^|\\.)youtube\\.com$|(^|\\.)youtu\\.be$|(^|\\.)vimeo\\.com$|(^|\\.)dailymotion\\.com$|(^|\\.)twitch\\.tv$|(^|\\.)instagram\\.com$/.test(host);
              const player = document.querySelector('.html5-video-player.ad-showing, .ad-showing, [class*="ad-interrupting"], .vp-ad-support, [class*="AdContainer"]');
              const selectors = [
                '.ytp-ad-text',
                '.ytp-ad-preview-text',
                '.ytp-ad-button-text',
                '.ytp-ad-visit-advertiser-button',
                '.ytp-ad-overlay-link',
                '.videoAdUiAttribution',
                '.videoAdUiTitle',
                '[class*="ad-simple-attributed-string"]',
                'button[aria-label*="Visit advertiser"]',
                'a[href*="adurl="]',
                'a[href*="googleadservices"]',
                'a[href*="doubleclick"]',
                '[class*="Sponsored"]',
                '[aria-label*="Sponsored"]'
              ];
              const bits = [];
              if (player) bits.push('video-ad');
              selectors.forEach((sel) => {
                try {
                  document.querySelectorAll(sel).forEach((el) => {
                    const t = ((el.innerText || el.textContent || el.getAttribute('aria-label') || '') + '')
                      .replace(/\\s+/g, ' ')
                      .trim();
                    if (t && t.length > 2 && t.length < 160 && !/^skip(\\s+ad)?$/i.test(t) && !/^ad$/i.test(t)) {
                      bits.push(t);
                    }
                    const href = el.getAttribute && (el.getAttribute('href') || el.getAttribute('data-url'));
                    if (href && /http/i.test(href)) bits.push(href);
                  });
                } catch (e) {}
              });
              const joined = Array.from(new Set(bits)).slice(0, 6).join(' · ');
              if (joined.length > 8 && (player || videoHost)) {
                postSubject(joined, player ? 'video-ad-overlay' : 'page-ad-overlay');
              }
            } catch (e) {}
          };

          const startObserver = () => {
            try {
              const root = document.documentElement || document;
              const mo = new MutationObserver((mutations) => {
                for (const mutation of mutations) {
                  mutation.addedNodes.forEach((node) => scanNode(node, 'dom'));
                }
                scrapeVideoAdSubject();
              });
              mo.observe(root, { childList: true, subtree: true });
            } catch (e) {}
          };

          if (document.documentElement) startObserver();
          else document.addEventListener('DOMContentLoaded', startObserver);

          setInterval(scrapeVideoAdSubject, 2500);
          setTimeout(scrapeVideoAdSubject, 1200);

          const reportTap = (ev) => {
            try {
              let el = ev.target;
              let href = null;
              let sponsored = false;
              let label = '';
              for (let i = 0; i < 14 && el; i++) {
                if (el.getAttribute) {
                  const candidate = el.getAttribute('href') || el.getAttribute('data-url') || el.getAttribute('data-href') || el.getAttribute('data-lynx-uri');
                  if (candidate && !href) href = candidate;
                }
                const t = ((el.innerText || el.textContent || '') + '').replace(/\\s+/g, ' ').trim();
                if (t && t.length < 120 && !label) label = t;
                if (/sponsored|paid partnership|advertisement|shop now|learn more|order now/i.test(t)) {
                  sponsored = true;
                  if (!label) label = t.slice(0, 80);
                }
                el = el.parentElement;
              }

              let absolute = href ? absoluteURL(href) : null;
              let external = false;
              try {
                if (absolute) {
                  const host = new URL(absolute).host;
                  external = !isMetaHost(host);
                }
              } catch (e) {}

              const looksAdRedirect = absolute && /ads\\/ig_redirect|l\\.instagram\\.com|l\\.facebook\\.com|lm\\.facebook\\.com|\\/l\\//i.test(absolute);
              if (sponsored || external || looksAdRedirect) {
                post({
                  kind: 'tap',
                  source: sponsored ? 'tap:sponsored' : (external ? 'tap:external' : 'tap:exit'),
                  url: absolute || location.href,
                  text: label || ''
                });
              } else if (absolute) {
                postURL(absolute, 'click');
              }
            } catch (e) {}
          };

          document.addEventListener('click', reportTap, true);
          document.addEventListener('pointerup', reportTap, true);

          if (window.PerformanceObserver) {
            try {
              const po = new PerformanceObserver((list) => {
                list.getEntries().forEach((entry) => {
                  if (entry && entry.name) postURL(entry.name, 'perf');
                });
              });
              po.observe({ type: 'resource', buffered: true });
            } catch (e) {}
          }
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: world
        )
    }
}
