import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var bookmarks: BookmarksStore
    @StateObject private var browser = BrowserViewModel()
    @State private var showBookmarks = false
    @State private var showTrafficLog = false
    @State private var showVault = false
    @State private var showPrivacyLab = false
    @FocusState private var addressFocused: Bool

    private var currentURLString: String {
        browser.webView.url?.absoluteString ?? browser.addressText
    }

    private var isCurrentBookmarked: Bool {
        bookmarks.isBookmarked(currentURLString)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if browser.isLoading && !browser.showingStartPage {
                ProgressView(value: browser.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(Color(red: 1.0, green: 0.42, blue: 0.0))
            }

            ZStack {
                BrowserWebView(webView: browser.webView)
                    .opacity(browser.showingStartPage ? 0 : 1)
                    .allowsHitTesting(!browser.showingStartPage)

                if browser.showingStartPage {
                    HomeStartView(
                        onOpenBookmark: { bookmark in
                            if let url = bookmark.url {
                                browser.open(url)
                            }
                        },
                        onOpenBlankURL: {
                            browser.beginBlankURLEntry()
                            DispatchQueue.main.async {
                                addressFocused = true
                            }
                        }
                    )
                    .environmentObject(bookmarks)
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.black)
        .sheet(isPresented: $showBookmarks) {
            BookmarksView { bookmark in
                if let url = bookmark.url {
                    browser.open(url)
                }
            }
            .environmentObject(bookmarks)
        }
        .sheet(isPresented: $showTrafficLog) {
            TrafficLogView(store: browser.trafficLog, pressure: browser.interestPressure)
        }
        .sheet(isPresented: $showVault) {
            AdVaultView(vault: browser.adVault)
        }
        .sheet(isPresented: $showPrivacyLab) {
            PrivacyLabView(engine: browser.obfuscation)
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    browser.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!browser.canGoBack || browser.showingStartPage)

                Button {
                    browser.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!browser.canGoForward || browser.showingStartPage)

                Button {
                    addressFocused = false
                    browser.goHome()
                } label: {
                    Image(systemName: "house.fill")
                }
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
                .accessibilityLabel("Home")

                TextField("Search or enter address", text: $browser.addressText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .focused($addressFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                    .onSubmit {
                        browser.loadAddressBar()
                        addressFocused = false
                    }

                Button {
                    if browser.isLoading {
                        browser.stop()
                    } else {
                        browser.reload()
                    }
                } label: {
                    Image(systemName: browser.isLoading ? "xmark" : "arrow.clockwise")
                }

                Button {
                    bookmarks.toggle(title: browser.pageTitle, urlString: currentURLString)
                } label: {
                    Image(systemName: isCurrentBookmarked ? "bookmark.fill" : "bookmark")
                }
                .disabled(browser.showingStartPage || URL(string: currentURLString)?.host == nil)

                Button {
                    showBookmarks = true
                } label: {
                    Image(systemName: "book")
                }

                Button {
                    showTrafficLog = true
                } label: {
                    Image(systemName: "waveform.path.ecg")
                }
                .accessibilityLabel("Ad traffic log")

                Button {
                    showVault = true
                } label: {
                    Image(systemName: "archivebox")
                }
                .accessibilityLabel("Ad vault")

                Button {
                    showPrivacyLab = true
                } label: {
                    Image(systemName: browser.obfuscation.isEnabled ? "theatermasks.fill" : "theatermasks")
                }
                .accessibilityLabel("Privacy lab")

                Menu {
                    Toggle(
                        "Block ads & trackers",
                        isOn: Binding(
                            get: { browser.contentBlockingEnabled },
                            set: { browser.setContentBlockingEnabled($0) }
                        )
                    )
                    Text(browser.blockerStatus)
                } label: {
                    Image(systemName: browser.contentBlockingEnabled ? "shield.lefthalf.filled" : "shield.slash")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
        .environmentObject(BookmarksStore())
}
