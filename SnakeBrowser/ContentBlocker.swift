import Foundation
import WebKit

enum ContentBlockerError: Error {
    case missingRulesFile
    case storeUnavailable
    case compileFailed
}

final class ContentBlocker {
    private(set) var compiledRules: WKContentRuleList?
    private let identifier = "snake.blocker.v2"

    @MainActor
    func prepare() async throws {
        guard let url = Bundle.main.url(forResource: "blockerList", withExtension: "json") else {
            throw ContentBlockerError.missingRulesFile
        }
        let data = try Data(contentsOf: url)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ContentBlockerError.missingRulesFile
        }

        guard let store = WKContentRuleListStore.default() else {
            throw ContentBlockerError.storeUnavailable
        }

        compiledRules = try await withCheckedThrowingContinuation { continuation in
            store.compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: json
            ) { list, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let list else {
                    continuation.resume(throwing: ContentBlockerError.compileFailed)
                    return
                }
                continuation.resume(returning: list)
            }
        }
    }

    @MainActor
    func apply(_ list: WKContentRuleList?, to webView: WKWebView) async {
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        if let list {
            controller.add(list)
        }
    }
}
