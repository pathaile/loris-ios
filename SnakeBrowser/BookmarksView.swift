import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject private var bookmarks: BookmarksStore
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Bookmark) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Tap the bookmark button while browsing to save a page.")
                    )
                } else {
                    List {
                        ForEach(bookmarks.bookmarks) { bookmark in
                            Button {
                                onSelect(bookmark)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(bookmark.urlString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .onDelete(perform: bookmarks.remove)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
