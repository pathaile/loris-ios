import Foundation
import Combine

@MainActor
final class BookmarksStore: ObservableObject {
    @Published private(set) var bookmarks: [Bookmark] = []

    private let defaultsKey = "snake.bookmarks"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isBookmarked(_ urlString: String) -> Bool {
        normalized(urlString).map { target in
            bookmarks.contains { normalized($0.urlString) == target }
        } ?? false
    }

    func toggle(title: String, urlString: String) {
        guard let target = normalized(urlString) else { return }
        if let index = bookmarks.firstIndex(where: { normalized($0.urlString) == target }) {
            bookmarks.remove(at: index)
        } else {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            bookmarks.insert(
                Bookmark(
                    title: cleanTitle.isEmpty ? target : cleanTitle,
                    urlString: target
                ),
                at: 0
            )
        }
        save()
    }

    func remove(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func remove(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey) else { return }
        do {
            bookmarks = try JSONDecoder().decode([Bookmark].self, from: data)
        } catch {
            bookmarks = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            defaults.set(data, forKey: defaultsKey)
        } catch {
            // Keep in-memory state if persistence fails.
        }
    }

    private func normalized(_ urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme != nil else {
            return nil
        }
        return url.absoluteString
    }
}
