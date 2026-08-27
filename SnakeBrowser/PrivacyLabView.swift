import SwiftUI

struct PrivacyLabView: View {
    @ObservedObject var engine: ObfuscationEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Personal on-device research lab. Mixes your browsing with benign decoy page loads to reduce how accurately trackers can infer interests. It does not automate paid-ad clicks, conversions, or checkout.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Obfuscation") {
                    Toggle("Enable decoy browsing", isOn: Binding(
                        get: { engine.isEnabled },
                        set: { engine.setEnabled($0) }
                    ))
                    Toggle("React to detected ads", isOn: $engine.reactToDetectedAds)
                        .disabled(!engine.isEnabled)
                    VStack(alignment: .leading) {
                        Text("Decoy interval: \(Int(engine.intervalSeconds))s")
                        Slider(value: $engine.intervalSeconds, in: 60...300, step: 15)
                            .disabled(!engine.isEnabled)
                            .onChange(of: engine.intervalSeconds) { _, _ in
                                if engine.isEnabled {
                                    engine.setEnabled(true) // reschedule timer
                                }
                            }
                    }
                    Button("Run one decoy now") {
                        engine.runDecoyNow()
                    }
                }

                Section("Stats") {
                    LabeledContent("Vaulted ads", value: "\(engine.vaultedCount)")
                    LabeledContent("Decoy loads", value: "\(engine.decoyCount)")
                    LabeledContent("Skipped billable URLs", value: "\(engine.skippedBillableCount)")
                    Text(engine.lastStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Policy") {
                    Text("• Detect & vault ads locally (AdNauseam-inspired vault concept)\n• Never auto-hit /aclk, ig_redirect, or other paid-click endpoints\n• Decoys load ordinary public pages in a hidden WebView\n• No purchases, signups, forms, or conversion simulation")
                        .font(.footnote)
                }
            }
            .navigationTitle("Privacy Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
