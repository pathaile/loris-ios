import Foundation
import Combine

@MainActor
final class TrafficLogStore: ObservableObject {
    @Published private(set) var entries: [TrafficLogEntry] = []

    private let maxEntries = 800
    private var recentKeys = Set<String>()
    private var recentOrder: [String] = []

    var blockedCount: Int { entries.filter { $0.kind == .blocked }.count }
    var trackerCount: Int { entries.filter { $0.kind == .tracker }.count }
    var adRequestCount: Int { entries.filter { $0.kind == .adRequest }.count }
    var adClickCount: Int { entries.filter { $0.kind == .adClick }.count }
    var tapCount: Int { entries.filter { $0.kind == .tap }.count }

    func clear() {
        entries.removeAll()
        recentKeys.removeAll()
        recentOrder.removeAll()
    }

    func append(
        kind: TrafficKind,
        summary: String,
        detail: String,
        pageHost: String? = nil,
        dedupeWindow: Bool = true
    ) {
        if dedupeWindow {
            let key = "\(kind.rawValue)|\(summary)|\(detail)"
            if recentKeys.contains(key) { return }
            recentKeys.insert(key)
            recentOrder.append(key)
            if recentOrder.count > 120 {
                let old = recentOrder.removeFirst()
                recentKeys.remove(old)
            }
        }

        entries.insert(
            TrafficLogEntry(kind: kind, summary: summary, detail: detail, pageHost: pageHost),
            at: 0
        )
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }
}
