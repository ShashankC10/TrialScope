import SwiftUI
import SwiftData
import TrialCore
#if canImport(UIKit)
import UIKit
#endif

struct TrialDetailView: View {
    let trial: Trial
    @Environment(\.modelContext) private var context
    @Query private var saved: [SavedTrial]
    @State private var error: String?
    @State private var showingShare = false
    @State private var showingNotes = false
    private var bookmark: SavedTrial? { saved.first { $0.trialID == trial.id } }
    private var shareText: String {
        "TrialScope demo study (fictional)\n\(trial.title)\n\(trial.condition) · \(trial.phase.rawValue)\n\(trial.location)\nID: \(trial.id)\nThis is sample data, not an actual trial or an eligibility determination."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(trial.condition.uppercased()).font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(Palette.ink)
                    Text(trial.title).font(.system(.largeTitle, design: .serif, weight: .medium))
                    StatusPill(status: trial.status)
                    Text(trial.id + " · Fictional study").font(.caption).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 20) {
                    fact("Phase", value: trial.phase.rawValue, icon: "chart.bar.xaxis")
                    fact("Location", value: trial.location, icon: "mappin.and.ellipse")
                    fact("Age range", value: trial.ageDescription, icon: "person")
                    fact("Updated", value: trial.updated, icon: "calendar")
                }.padding(20).background(Palette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                detailSection("About this study") { Text(trial.summary).foregroundStyle(.secondary) }
                detailSection("Who may be considered") { criteria(trial.inclusion, icon: "checkmark.circle", color: Palette.ink) }
                detailSection("Criteria to discuss") { criteria(trial.exclusion, icon: "minus.circle", color: .secondary) }
                Label("A search match does not confirm eligibility. A real study team would review the full criteria with you.", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(16).background(.background, in: RoundedRectangle(cornerRadius: 16))
                detailSection("Study organization") { Text(trial.sponsor).foregroundStyle(.secondary) }
                if let bookmark {
                    detailSection("Your notes") {
                        Text(bookmark.notes.isEmpty ? "Keep questions or details you want to revisit." : bookmark.notes).foregroundStyle(.secondary)
                        Button(bookmark.notes.isEmpty ? "Add a note" : "Edit note") { showingNotes = true }
                            .buttonStyle(.bordered).accessibilityIdentifier("editNoteButton")
                    }
                }
                DemoNotice()
            }.padding(24).readableWidth()
        }
        .canvas().navigationTitle("Study details").inlineTitle()
        .safeAreaInset(edge: .bottom) {
            Button {
                do {
                    if bookmark != nil { try TrialStore.remove(id: trial.id, in: context) }
                    else { try TrialStore.save(trial, in: context) }
                } catch { self.error = error.localizedDescription }
            } label: {
                Label(bookmark == nil ? "Save study" : "Remove from saved", systemImage: bookmark == nil ? "bookmark" : "bookmark.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(8)
            }.buttonStyle(.borderedProminent).tint(Palette.teal).controlSize(.large).accessibilityIdentifier("saveStudyButton")
                .padding(.horizontal, 24).padding(.vertical, 12).readableWidth().background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                #if canImport(UIKit)
                Button { showingShare = true } label: { Label("Share study", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("shareStudyButton")
                #else
                ShareLink(item: shareText)
                #endif
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingShare) { ActivitySheet(text: shareText).presentationDetents([.medium, .large]) }
        #endif
        .sheet(isPresented: $showingNotes) { if let bookmark { NoteEditor(saved: bookmark) } }
        .alert("Couldn’t update saved study", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func fact(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.title3.weight(.semibold)); content() }
    }
    private func criteria(_ items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon).foregroundStyle(color)
                    Text(item).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct NoteEditor: View {
    let saved: SavedTrial
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var error: String?
    init(saved: SavedTrial) { self.saved = saved; _text = State(initialValue: saved.notes) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text).frame(minHeight: 180).accessibilityLabel("Study notes").accessibilityIdentifier("noteEditor")
                } footer: { Text("Notes are stored on this device. Use fictional information while testing this demo.") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Your notes").inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try TrialStore.updateNotes(text, for: saved, in: context); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("saveNoteButton")
                }
            }
        }
    }
}

#if canImport(UIKit)
/// Native UIKit sharing bridged into SwiftUI; no data leaves until the user chooses a destination.
struct ActivitySheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
