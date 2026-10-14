import SwiftUI
import TrialCore

/// Saved studies use TrialDetailView directly and never require a connection.
struct LoadedTrialDetailView: View {
    let trial: Trial
    let service: any TrialService
    @State private var loaded: Trial?
    @State private var error: String?
    @State private var attempt = 0
    var body: some View {
        Group {
            if let loaded { TrialDetailView(trial: loaded) }
            else { placeholder }
        }
        .task(id: attempt) {
            error = nil
            do {
                let detail = try await service.detail(for: trial)
                try Task.checkCancellation()
                loaded = detail
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }

    /// Shows what the list already knew while the full record loads, instead of a blank screen.
    private var placeholder: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(trial.primaryCondition).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(trial.title).font(.system(.title, design: .serif, weight: .semibold))
                if let error {
                    ContentUnavailableView {
                        Label("Couldn’t load study details", systemImage: "wifi.exclamationmark")
                    } description: { Text(error) } actions: {
                        Button("Try again") { attempt += 1 }.buttonStyle(.borderedProminent).tint(Palette.teal)
                    }
                } else {
                    HStack(spacing: 10) { ProgressView(); Text("Loading full details…").foregroundStyle(.secondary) }
                        .padding(.top, 8)
                }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).readableWidth()
        }
        .canvas().navigationTitle("Study details").inlineTitle()
    }
}
