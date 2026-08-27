import SwiftUI

struct TrafficLogGuideView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    sectionHeader("Reading the feed")
                    Text("Newest events appear at the top. Each row’s color bar matches its type. Tap a filter chip on the log to show one kind only.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.65))

                    sectionHeader("Event types")
                    ForEach(guideRows) { row in
                        guideCard(row)
                    }

                    sectionHeader("AD PRESSURE panel")
                    pressureCard

                    sectionHeader("Privacy lab flow")
                    flowCard

                    sectionHeader("What Loris never does")
                    Text("It does not auto-click paid ads or follow billable redirect URLs. Detected click targets are vaulted and skipped; decoys load ordinary public pages in the background.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.65))
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("How to read this")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOG GUIDE")
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color(red: 0.39, green: 0.82, blue: 1.0))
            Text("Color-coded key for every line in Ad Traffic.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(Color.white.opacity(0.4))
    }

    private func guideCard(_ row: GuideRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(row.color)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(row.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(row.color)
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(row.body)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(row.color.opacity(0.28), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var pressureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AD PRESSURE")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.30))
            Text("What ads are pushing you toward")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("Scores subjects inferred from ad text, overlays, and vaulted targets (telecom, fashion, finance, etc.). Expand the panel for ranked topics. Decoy browsing prefers categories that cut against the top subject.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 1.0, green: 0.55, blue: 0.30).opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var flowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            flowStep(TrafficKind.tap.color, "You tap something ad-like")
            flowStep(TrafficKind.adClick.color, "EXIT CLICK if it leaves via an ad redirect")
            flowStep(TrafficKind.vault.color, "VAULT stores the target URL")
            flowStep(TrafficKind.skipped.color, "SKIPPED if that URL looks billable")
            flowStep(TrafficKind.subject.color, "SUBJECT updates AD PRESSURE")
            flowStep(TrafficKind.decoy.color, "DECOY loads a counter-interest public page")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func flowStep(_ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var guideRows: [GuideRow] {
        [
            GuideRow(
                kind: .blocked,
                title: "Filter stopped a request",
                body: "An ad or tracker URL matched the blocker list and was not loaded."
            ),
            GuideRow(
                kind: .tracker,
                title: "Tracker traffic seen",
                body: "Analytics or tracking request classified by the matcher. May appear more when blocking is off."
            ),
            GuideRow(
                kind: .adRequest,
                title: "Ad link discovered (not a click)",
                body: "An ad-related URL showed up in the page, network, or DOM. Seeing it ≠ you clicked it."
            ),
            GuideRow(
                kind: .adClick,
                title: "You left via an ad path",
                body: "User-driven navigation through an ad redirect (e.g. Instagram ig_redirect) or off-site leave."
            ),
            GuideRow(
                kind: .tap,
                title: "Your finger on the page",
                body: "A tap on something that looked sponsored, external, or ad-redirect related."
            ),
            GuideRow(
                kind: .vault,
                title: "Saved for research",
                body: "Detected ad target stored in the Ad Vault so you can inspect it later."
            ),
            GuideRow(
                kind: .skipped,
                title: "Billable URL refused",
                body: "Loris would not auto-visit a paid-click / conversion URL. Logged and left alone."
            ),
            GuideRow(
                kind: .subject,
                title: "Inferred ad topic",
                body: "Keywords from overlays, tap text, or URLs mapped to a commercial subject (fashion, telecom, etc.)."
            ),
            GuideRow(
                kind: .decoy,
                title: "Background counter-browse",
                body: "Hidden load of a public, non-billable page chosen against current AD PRESSURE."
            ),
            GuideRow(
                kind: .page,
                title: "Normal page navigation",
                body: "Ordinary browsing in the main web view."
            ),
            GuideRow(
                kind: .info,
                title: "System note",
                body: "Status messages: filters ready, obfuscation on/off, and similar."
            )
        ]
    }
}

private struct GuideRow: Identifiable {
    let kind: TrafficKind
    let title: String
    let body: String

    var id: String { kind.rawValue }
    var label: String { kind.label }
    var color: Color { kind.color }
}
