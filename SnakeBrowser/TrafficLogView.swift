import SwiftUI
import UIKit

struct TrafficLogView: View {
    @ObservedObject var store: TrafficLogStore
    @ObservedObject var pressure: InterestPressureStore
    @Environment(\.dismiss) private var dismiss
    @State private var filter: TrafficKind? = nil
    @State private var didCopy = false
    @State private var showGuide = false

    private var visibleEntries: [TrafficLogEntry] {
        guard let filter else { return store.entries }
        return store.entries.filter { $0.kind == filter }
    }

    private var exportText: String {
        let pressureLine: String
        if let dominant = pressure.dominant {
            pressureLine = "AdPressure=\(dominant.label) score=\(String(format: "%.1f", dominant.score)) counters=\(pressure.counterDecoyCategoryIDs().joined(separator: ","))"
        } else {
            pressureLine = "AdPressure=none"
        }
        let header = [
            "Loris Ad Traffic Export",
            "Filter: \(filter?.label ?? "ALL")",
            "Blocked=\(store.blockedCount) Trackers=\(store.trackerCount) AdHits=\(store.adRequestCount) ExitClicks=\(store.adClickCount) Taps=\(store.tapCount)",
            pressureLine,
            "Exported: \(ISO8601DateFormatter().string(from: Date()))",
            ""
        ].joined(separator: "\n")

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        let lines = visibleEntries.map { entry in
            let time = formatter.string(from: entry.timestamp)
            let page = entry.pageHost.map { " | on \($0)" } ?? ""
            return "[\(time)] \(entry.kind.label) | \(entry.summary) | \(entry.detail)\(page)"
        }

        return header + lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    legend
                    stats
                    InterestPressurePanel(pressure: pressure)
                    Divider().overlay(Color.white.opacity(0.12))

                    if visibleEntries.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(visibleEntries) { entry in
                                    logRow(entry)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
            .navigationTitle("Ad Traffic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .foregroundStyle(Color(red: 0.39, green: 0.82, blue: 1.0))
                    .accessibilityLabel("How to read this log")

                    Button {
                        UIPasteboard.general.string = exportText
                        didCopy = true
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            didCopy = false
                        }
                    } label: {
                        Text(didCopy ? "Copied" : "Copy")
                    }
                    .foregroundStyle(didCopy ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 0.39, green: 0.82, blue: 1.0))
                    .disabled(visibleEntries.isEmpty)

                    Button("Clear") {
                        store.clear()
                        pressure.clear()
                    }
                        .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.23))
                }
            }
            .navigationDestination(isPresented: $showGuide) {
                TrafficLogGuideView()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, title: "ALL", color: .white)
                ForEach(TrafficKind.allCases) { kind in
                    filterChip(kind, title: kind.label, color: kind.color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(white: 0.07))
    }

    private func filterChip(_ kind: TrafficKind?, title: String, color: Color) -> some View {
        let selected = filter == kind
        return Button {
            filter = kind
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? color.opacity(0.25) : Color.white.opacity(0.06))
                .foregroundStyle(selected ? color : color.opacity(0.85))
                .overlay(
                    Capsule().stroke(color.opacity(selected ? 1 : 0.35), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                stat("Blocked", store.blockedCount, TrafficKind.blocked.color)
                stat("Ad hits", store.adRequestCount, TrafficKind.adRequest.color)
                stat("Exit", store.adClickCount, TrafficKind.adClick.color)
                stat("Taps", store.tapCount, TrafficKind.tap.color)
            }
            Text("Pink TAP = your tap. Magenta EXIT = leave/ad-redirect. Yellow AD HIT = ad links seen. Amber SUBJECT = inferred ad topic. Blue VAULT / teal DECOY / orange SKIPPED = privacy lab. AD PRESSURE shows what ads push toward; decoys steer the other way.")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .background(Color(white: 0.07))
    }

    private func stat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("No traffic yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Browse a few sites with ads. Blocked and ad-related requests will show up here.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }

    private func logRow(_ entry: TrafficLogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.kind.color)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.kind.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(entry.kind.color)
                    Spacer()
                    Text(entry.timestamp, style: .time)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                Text(entry.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.detail)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(3)
                if let pageHost = entry.pageHost {
                    Text("on \(pageHost)")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
        }
        .padding(10)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(entry.kind.color.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
