import SwiftUI

@main
struct SnakeBrowserApp: App {
    @StateObject private var bookmarks = BookmarksStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookmarks)
        }
    }
}
