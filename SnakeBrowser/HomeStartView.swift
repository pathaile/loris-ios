import SwiftUI

struct HomeStartView: View {
    @EnvironmentObject private var bookmarks: BookmarksStore
    let onOpenBookmark: (Bookmark) -> Void
    let onOpenBlankURL: () -> Void

    private let orange = Color(red: 1.0, green: 0.45, blue: 0.08)
    private let desertTan = Color(red: 0.82, green: 0.70, blue: 0.48)
    private let olive = Color(red: 0.36, green: 0.45, blue: 0.28)

    private let columns = [
        GridItem(.adaptive(minimum: 72, maximum: 88), spacing: 18)
    ]

    var body: some View {
        ZStack {
            Image("LorisHomeBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("LORIS")
                        .font(.system(size: 44, weight: .black, design: .serif))
                        .tracking(8)
                        .foregroundStyle(orange)
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)

                    Text("Browse quiet. Profile noisy.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.32, blue: 0.18))
                }
                .padding(.top, 28)
                .padding(.bottom, 20)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("BOOKMARKS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Color(red: 0.42, green: 0.32, blue: 0.18))

                    LazyVGrid(columns: columns, spacing: 18) {
                        Button {
                            onOpenBlankURL()
                        } label: {
                            BlankURLIconCell(accent: orange)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open blank URL")

                        ForEach(bookmarks.bookmarks.prefix(15)) { bookmark in
                            Button {
                                onOpenBookmark(bookmark)
                            } label: {
                                BookmarkIconCell(bookmark: bookmark, accent: orange, tan: desertTan)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if bookmarks.bookmarks.isEmpty {
                        Text("Tap URL to type an address. Save pages with the bookmark button to pin them here.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(red: 0.42, green: 0.32, blue: 0.18).opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.48))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(olive.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 18)

                Spacer(minLength: 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BlankURLIconCell: View {
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.95),
                                Color(red: 0.85, green: 0.35, blue: 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: accent.opacity(0.35), radius: 6, y: 2)

                Image(systemName: "link")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("URL")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.28, green: 0.20, blue: 0.12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
    }
}

private struct BookmarkIconCell: View {
    let bookmark: Bookmark
    let accent: Color
    let tan: Color

    private var host: String {
        bookmark.url?.host?.replacingOccurrences(of: "www.", with: "") ?? "site"
    }

    private var faviconURL: URL? {
        guard let host = bookmark.url?.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128")
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.black.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(accent.opacity(0.45), lineWidth: 1)
                    )
                    .frame(width: 58, height: 58)

                if let faviconURL {
                    AsyncImage(url: faviconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        default:
                            Text(String(host.prefix(1)).uppercased())
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(accent)
                        }
                    }
                } else {
                    Text("?")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                }
            }

            Text(bookmark.title.isEmpty ? host : bookmark.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.28, green: 0.20, blue: 0.12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
    }
}
