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
        "\(trial.isDemo ? "TrialScope demo study (fictional)" : "Clinical study")\n\(trial.title)\n\(trial.condition) · \(trial.phaseDescription)\n\(trial.location)\nID: \(trial.id)\n\(trial.isDemo ? "Fictional sample data. " : "")A search match is not an eligibility determination."
    }
    private var inclusion: [String] { CriteriaText.items(from: trial.inclusion) }
    private var exclusion: [String] { CriteriaText.items(from: trial.exclusion) }
    private var rawCriteria: String? {
        guard let raw = trial.rawEligibility?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                facts
                if trial.hasSummary { section("About this study") { Text(trial.summary).font(.body) } }
                eligibility
                EligibilityNote()
                if trial.sponsor != "Not provided by the API", trial.sponsor != "Not provided" {
                    section("Study organization") { Text(trial.sponsor).foregroundStyle(.secondary) }
                }
                notes
                if trial.isDemo { DemoNotice() }
            }.padding(.horizontal, 22).padding(.vertical, 16).readableWidth()
        }
        .canvas().navigationTitle("Study details").inlineTitle()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                saveButton
                #if canImport(UIKit)
                Button { showingShare = true } label: { Label("Share study", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("shareStudyButton")
                #else
                ShareLink(item: shareText)
                #endif
            }
        }
        .sensoryFeedback(.success, trigger: bookmark != nil)
        #if canImport(UIKit)
        .sheet(isPresented: $showingShare) { ActivitySheet(text: shareText).presentationDetents([.medium, .large]) }
        #endif
        .sheet(isPresented: $showingNotes) { if let bookmark { NoteEditor(saved: bookmark) } }
        .alert("Couldn’t update saved study", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: Pieces

    private var saveButton: some View {
        Button {
            do {
                if bookmark != nil { try TrialStore.remove(id: trial.id, in: context) }
                else { try TrialStore.save(trial, in: context) }
            } catch { self.error = error.localizedDescription }
        } label: {
            Label(bookmark == nil ? "Save study" : "Remove from saved", systemImage: bookmark == nil ? "bookmark" : "bookmark.fill")
                .symbolEffect(.bounce, value: bookmark != nil)
        }
        .accessibilityIdentifier("saveStudyButton")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowLayout(spacing: 6) {
                ForEach(Array(trial.conditionList.prefix(3).enumerated()), id: \.offset) { _, name in
                    Text(name).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Palette.teal.opacity(0.1), in: Capsule())
                }
                if trial.conditionList.count > 3 {
                    Text("+\(trial.conditionList.count - 3) more").font(.caption).foregroundStyle(.secondary).padding(.vertical, 5)
                }
            }
            Text(trial.title).font(.system(.title, design: .serif, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 8) {
                StatusPill(status: trial.status, text: trial.statusDescription)
                PhasePill(trial: trial)
            }
            Text(trial.id + (trial.isDemo ? " · Fictional study" : "")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 0) {
            factRow("Age", value: trial.ageDescription, icon: "person")
            Divider().padding(.leading, 44)
            factRow("Location", value: trial.location, icon: "mappin.and.ellipse",
                    detail: trial.additionalSiteCount > 0 ? "+\(trial.additionalSiteCount) more sites" : nil)
            if trial.updated != "Not provided" {
                Divider().padding(.leading, 44)
                factRow("Updated", value: trial.updated, icon: "calendar")
            }
            if trial.additionalSiteCount > 0 {
                Divider().padding(.leading, 44)
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(trial.sites.enumerated()), id: \.offset) { _, site in
                            Text(site).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(.top, 8)
                } label: {
                    Label("All \(trial.sites.count) study sites", systemImage: "list.bullet").font(.subheadline)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).tint(Palette.ink)
            }
        }
        .surface(radius: 18)
    }

    @ViewBuilder private var eligibility: some View {
        if !inclusion.isEmpty || !exclusion.isEmpty {
            if !inclusion.isEmpty {
                section("Who may be considered") { criteria(inclusion, icon: "checkmark.circle.fill", color: Palette.teal) }
            }
            if !exclusion.isEmpty {
                section("Criteria to discuss with the study team") { criteria(exclusion, icon: "exclamationmark.circle", color: Palette.amber) }
            }
            if let raw = rawCriteria, raw != trial.inclusion.joined() {
                DisclosureGroup("Original criteria text") {
                    Text(raw).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }.tint(Palette.ink).padding(16).surface(radius: 16)
            }
        } else if let raw = rawCriteria {
            section("Eligibility criteria") {
                Text(raw).font(.subheadline).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16).surface(radius: 16)
            }
        }
    }

    @ViewBuilder private var notes: some View {
        if let bookmark {
            section("Your notes") {
                Text(bookmark.notes.isEmpty ? "Keep questions or details you want to revisit." : bookmark.notes)
                    .foregroundStyle(bookmark.notes.isEmpty ? .secondary : .primary)
                Button(bookmark.notes.isEmpty ? "Add a note" : "Edit note") { showingNotes = true }
                    .buttonStyle(.bordered).tint(Palette.teal).accessibilityIdentifier("editNoteButton")
            }
        } else {
            Label("Save this study to keep private notes on this device.", systemImage: "bookmark")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func factRow(_ title: String, value: String, icon: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.ink).frame(width: 20).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold))
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func criteria(_ items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: icon).foregroundStyle(color).accessibilityHidden(true)
                    Text(item).font(.subheadline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).surface(radius: 16)
    }
}

/// Turns criteria blobs ("* First\n* Second") into readable items and drops placeholders.
enum CriteriaText {
    static func items(from sections: [String]) -> [String] {
        sections.flatMap { section in
            section.split(whereSeparator: \.isNewline).map { line -> String in
                var text = line.trimmingCharacters(in: .whitespaces)
                while let first = text.first, "*-•–·".contains(first) { text.removeFirst(); text = text.trimmingCharacters(in: .whitespaces) }
                return text
            }
        }
        .filter { !$0.isEmpty && $0 != "Not provided" && $0.range(of: #"^(inclusion|exclusion) criteria:?$"#, options: [.regularExpression, .caseInsensitive]) == nil }
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
                } footer: { Text("Notes are stored on this device and are not sent to the search server.") }
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
