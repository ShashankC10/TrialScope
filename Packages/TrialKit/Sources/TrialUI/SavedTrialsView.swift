import SwiftUI
import SwiftData
import TrialCore

struct SavedTrialsView: View {
    @Query(sort: \SavedTrial.savedAt, order: .reverse) private var saved: [SavedTrial]
    @Environment(\.modelContext) private var context
    @State private var error: String?
    private var uniqueSaved: [SavedTrial] {
        var seen = Set<String>()
        return saved.filter { seen.insert($0.trialID).inserted }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionTitle(title: "Worth a closer look.", subtitle: "Your saved studies and notes, available offline.")
                if uniqueSaved.isEmpty {
                    ContentUnavailableView("Your shortlist starts here", systemImage: "bookmark",
                                           description: Text("Save a study from Discover to keep its details close at hand."))
                        .padding(.top, 50).accessibilityIdentifier("savedEmptyState")
                } else {
                    ForEach(uniqueSaved) { saved in
                        if let trial = saved.trial {
                            NavigationLink { TrialDetailView(trial: trial) } label: { TrialCard(trial: trial, saved: true) }
                                .buttonStyle(.plain).accessibilityIdentifier("saved-\(trial.id)")
                                .contextMenu {
                                    Button("Remove saved study", role: .destructive) { remove(saved) }
                                }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("This saved study couldn’t be read.")
                                Button("Remove unreadable study", role: .destructive) { remove(saved) }
                            }.padding()
                        }
                    }
                }
                DemoNotice()
            }.padding(20).readableWidth()
        }.canvas().navigationTitle("Saved studies")
        .alert("Couldn’t remove study", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
    private func remove(_ saved: SavedTrial) {
        do { try TrialStore.remove(id: saved.trialID, in: context) }
        catch { self.error = error.localizedDescription }
    }
}
