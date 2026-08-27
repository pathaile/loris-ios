import SwiftUI

struct AdVaultView: View {
    @ObservedObject var vault: AdVaultStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if vault.ads.isEmpty {
                    ContentUnavailableView(
                        "Ad Vault empty",
                        systemImage: "archivebox",
                        description: Text("Detected ads are stored here locally for research. Billable click URLs are recorded but never auto-visited.")
                    )
                    .foregroundStyle(.white)
                } else {
                    List {
                        ForEach(vault.ads) { ad in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(ad.targetHost ?? "unknown")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if ad.isBillableClickURL {
                                        Text("BILLABLE?")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.30))
                                    }
                                }
                                if let title = ad.titleHint, !title.isEmpty {
                                    Text(title)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.8))
                                }
                                Text(ad.targetURL)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Color.white.opacity(0.55))
                                    .lineLimit(3)
                                Text("\(ad.source) · \(ad.notes)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                            .listRowBackground(Color(white: 0.1))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                vault.remove(vault.ads[index])
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Ad Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { vault.clear() }
                        .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.23))
                        .disabled(vault.ads.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
