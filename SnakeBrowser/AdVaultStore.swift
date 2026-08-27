import Foundation
import Combine

@MainActor
final class AdVaultStore: ObservableObject {
    @Published private(set) var ads: [VaultedAd] = []

    private let defaultsKey = "snake.adVault.v1"
    private let defaults: UserDefaults
    private let maxAds = 500

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Returns the vaulted ad and whether this call created a new vault entry.
    @discardableResult
    func record(
        targetURL: String,
        pageHost: String?,
        pageURL: String?,
        source: String,
        titleHint: String? = nil
    ) -> (ad: VaultedAd, isNew: Bool)? {
        let trimmed = targetURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else { return nil }

        let key = Self.dedupeKey(for: trimmed)

        if let existing = ads.first(where: { Self.dedupeKey(for: $0.targetURL) == key }),
           Date().timeIntervalSince(existing.detectedAt) < 300 {
            return (existing, false)
        }

        let ad = VaultedAd(
            pageHost: pageHost,
            pageURL: pageURL,
            targetURL: trimmed,
            source: source,
            titleHint: titleHint,
            notes: PaidClickPolicy.isLikelyBillableClickURL(trimmed)
                ? "Marked billable-click URL; vaulted only, not auto-visited."
                : "Vaulted for local research history."
        )
        ads.insert(ad, at: 0)
        if ads.count > maxAds {
            ads = Array(ads.prefix(maxAds))
        }
        save()
        return (ad, true)
    }

    func remove(_ ad: VaultedAd) {
        ads.removeAll { $0.id == ad.id }
        save()
    }

    func clear() {
        ads.removeAll()
        save()
    }

    /// Prefer Meta `hash=` when present; otherwise strip ephemeral open params.
    static func dedupeKey(for urlString: String) -> String {
        guard let url = URL(string: urlString),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return urlString
        }
        let items = components.queryItems ?? []
        if let hash = items.first(where: { $0.name == "hash" })?.value, !hash.isEmpty {
            return "hash:\(hash)"
        }
        let ephemeral = Set(["e", "g", "__tn__", "fbclid", "campaign_id"])
        components.queryItems = items.filter { !ephemeral.contains($0.name) }
        return components.string ?? urlString
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey) else { return }
        ads = (try? JSONDecoder().decode([VaultedAd].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ads) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
