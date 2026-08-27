import SwiftUI

struct InterestPressurePanel: View {
    @ObservedObject var pressure: InterestPressureStore
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AD PRESSURE")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.30))
                        Text(pressure.pressureSummary)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        if let dominant = pressure.dominant {
                            Text("Decoys steer away from this toward \(counterBlurb(for: dominant.id)).")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.45))
                        } else {
                            Text("As ads are detected (including video overlays), their subject shows up here.")
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if pressure.ranked.isEmpty {
                    Text("No subjects inferred yet.")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.4))
                } else {
                    ForEach(pressure.ranked.prefix(6)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(String(format: "%.0f", item.score))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.30))
                            }
                            GeometryReader { geo in
                                let maxScore = max(pressure.ranked.first?.score ?? 1, 1)
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(Color(red: 1.0, green: 0.45, blue: 0.08))
                                            .frame(width: geo.size.width * CGFloat(item.score / maxScore))
                                    }
                            }
                            .frame(height: 6)
                            if !item.examples.isEmpty {
                                Text(item.examples.joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .lineLimit(2)
                            }
                        }
                        .padding(.top, 4)
                    }
                    Button("Reset pressure") {
                        pressure.clear()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
                    .padding(.top, 6)
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 1.0, green: 0.55, blue: 0.30).opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func counterBlurb(for subjectID: String) -> String {
        let ids = pressure.counterDecoyCategoryIDs()
        return ids.prefix(3).joined(separator: ", ")
    }
}
