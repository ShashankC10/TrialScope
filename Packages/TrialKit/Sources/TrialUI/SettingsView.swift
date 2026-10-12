import SwiftUI
import TrialCore

struct SettingsView: View {
    let service: MockTrialService
    @State private var fail = false
    @State private var slow = false
    var body: some View {
        Form {
            Section {
                Label("TrialScope", systemImage: "leaf.circle.fill").font(.title2.weight(.semibold)).foregroundStyle(Palette.ink)
                Text("A quieter way to explore clinical research.").foregroundStyle(.secondary)
                LabeledContent("Build", value: "1.0 · Portfolio demo")
            }
            Section("Your data") {
                Label("Saved studies stay on this device", systemImage: "iphone")
                Label("No accounts or analytics", systemImage: "hand.raised")
                Label("No network requests", systemImage: "wifi.slash")
                Text("Search terms and age filters are held only for the current session. Bookmarks and notes are saved locally with SwiftData. Cloud sync is disabled in this build.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Simulate service failure", isOn: $fail).accessibilityIdentifier("failureToggle")
                Toggle("Simulate slow responses", isOn: $slow).accessibilityIdentifier("slowToggle")
            } header: { Text("Demo controls") } footer: {
                Text("Applies to the next search or page request. Turn failure off, then retry from Discover. These controls reset when the app restarts.")
            }
            Section("About the catalog") {
                Text("All 18 studies, organizations, and criteria are fictional fixtures. Search uses deterministic keyword matching, not the real search engine or an AI eligibility model.")
                Text("This prototype is for exploring the app experience. It does not provide clinical recommendations or enrollment.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task(id: "\(fail)-\(slow)") { await service.configure(shouldFail: fail, slow: slow) }
    }
}
