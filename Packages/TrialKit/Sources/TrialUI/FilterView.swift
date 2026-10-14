import SwiftUI
import TrialCore

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SearchRequest
    @State private var ageText: String
    let apply: (SearchRequest) -> Void

    init(initial: SearchRequest, apply: @escaping (SearchRequest) -> Void) {
        _draft = State(initialValue: initial)
        _ageText = State(initialValue: initial.age.map(String.init) ?? "")
        self.apply = apply
    }
    private var validAge: Bool {
        ageText.isEmpty || Int(ageText).map { (0...120).contains($0) } == true
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Availability") { Toggle("Recruiting only", isOn: $draft.recruitingOnly).accessibilityIdentifier("recruitingToggle") }
                Section("Study phase") {
                    Picker("Phase", selection: $draft.phase) {
                        Text("Any phase").tag(Optional<TrialPhase>.none)
                        ForEach(TrialPhase.allCases.filter { $0 != .unknown }, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                    }
                }
                Section {
                    TextField("Age in years (optional)", text: $ageText).accessibilityIdentifier("ageField")
                    if !validAge { Text("Enter a whole number from 0 to 120.").font(.caption).foregroundStyle(.red) }
                } header: { Text("Age range") } footer: {
                    Text("Filters the study’s listed age range only. In API mode, age is sent to the server. Observational narrows only the returned top-20 results; it is not a server-wide filter.")
                }
                Section { Button("Reset filters") { draft = SearchRequest(); ageText = "" } }
            }
            .navigationTitle("Refine your search").inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { draft.age = Int(ageText); apply(draft); dismiss() }
                        .disabled(!validAge).accessibilityIdentifier("applyFiltersButton")
                }
            }
        }
    }
}
