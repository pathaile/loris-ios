import Foundation

struct DecoyCategory: Identifiable, Codable {
    let id: String
    let label: String
    let urls: [String]
}

struct DecoyCatalogFile: Codable {
    let categories: [DecoyCategory]
}

struct DecoyCatalog {
    let categories: [DecoyCategory]

    static func loadFromBundle() -> DecoyCatalog {
        guard let url = Bundle.main.url(forResource: "decoyCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(DecoyCatalogFile.self, from: data) else {
            return DecoyCatalog(categories: [])
        }
        return DecoyCatalog(categories: file.categories)
    }

    func randomTarget(preferringCategoryIDs preferred: [String] = []) -> (category: DecoyCategory, url: URL)? {
        let usable = categories.filter { cat in
            cat.urls.contains { PaidClickPolicy.isSafePublicNavigationURL($0) }
        }
        guard !usable.isEmpty else { return nil }

        let preferredUsable = usable.filter { preferred.contains($0.id) }
        let pool = preferredUsable.isEmpty ? usable : preferredUsable
        guard let category = pool.randomElement() else { return nil }

        let safe = category.urls.compactMap { raw -> URL? in
            guard PaidClickPolicy.isSafePublicNavigationURL(raw) else { return nil }
            return URL(string: raw)
        }
        guard let url = safe.randomElement() else { return nil }
        return (category, url)
    }
}
