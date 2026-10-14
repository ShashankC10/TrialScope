import SwiftUI
import TrialCore

struct SettingsView: View {
    let service: any TrialService
    private var mock: MockTrialService? { service as? MockTrialService }
    @State private var fail = false
    @State private var slow = false
    var body: some View {
        Form {
            Section {
                Label("TrialScope", systemImage: "leaf.circle.fill").font(.title2.weight(.semibold)).foregroundStyle(Palette.ink)
                Text("A quieter way to explore clinical research.").foregroundStyle(.secondary)
                LabeledContent("Build", value: mock == nil ? "1.0 · API" : "1.0 · Demo")
            }
            Section("Your data") {
                Label("Saved studies stay on this device", systemImage: "iphone")
                Label("No accounts or analytics", systemImage: "hand.raised")
                Label(mock == nil ? "Searches are sent to your configured server" : "No network requests", systemImage: mock == nil ? "network" : "wifi.slash")
                Text("Search terms and age filters are not saved on this device. In API mode they are sent to the server, whose logging and retention settings apply. Bookmarks and notes are saved locally with SwiftData. Cloud sync is disabled in this build.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if mock != nil { Section {
                Toggle("Simulate service failure", isOn: $fail).accessibilityIdentifier("failureToggle")
                Toggle("Simulate slow responses", isOn: $slow).accessibilityIdentifier("slowToggle")
            } header: { Text("Demo controls") } footer: {
                Text("Applies to the next search or page request. Turn failure off, then retry from Discover. These controls reset when the app restarts.")
            }
            }
            Section("About the catalog") {
                Text(mock == nil ? "Search returns up to 20 ranked matches from the configured clinical trial server. Details are fetched when you open a study. Saved snapshots remain available offline." : "All 18 studies and criteria are fictional fixtures. Demo search uses deterministic keyword matching.")
                Text("This prototype is for exploring the app experience. It does not provide clinical recommendations or enrollment.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task(id: "\(fail)-\(slow)") { await mock?.configure(shouldFail: fail, slow: slow) }
    }
}
