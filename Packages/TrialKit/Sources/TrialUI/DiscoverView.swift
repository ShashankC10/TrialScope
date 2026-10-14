import SwiftUI
import SwiftData
import TrialCore

struct DiscoverView: View {
    @Bindable var model: SearchModel
    let service: any TrialService
    private var isDemo: Bool { service is MockTrialService }
    @Query private var saved: [SavedTrial]
    @State private var query = ""
    @State private var filters = SearchRequest()
    @State private var showFilters = false
    @FocusState private var searchFocused: Bool
    private let suggestions = ["Breast cancer", "Diabetes", "Migraine", "Heart"]

    private var request: SearchRequest {
        var request = filters
        request.query = query
        return request
    }
    private var isBrowsing: Bool { query.isEmpty && filters.activeFilterCount == 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isBrowsing && model.request.query.isEmpty { header }
                searchBox
                filterRow
                if isBrowsing { topics }
                results
            }.padding(.horizontal, 20).padding(.vertical, 12).readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .canvas()
        .navigationTitle("TrialScope")
        .inlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showFilters = true } label: {
                    Label(filters.activeFilterCount == 0 ? "Filters" : "Filters (\(filters.activeFilterCount))", systemImage: "line.3.horizontal.decrease")
                }.accessibilityIdentifier("filtersButton")
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterView(initial: filters) { filters = $0; model.search(request) }
        }
        .task { if model.state == .idle { model.search(request) } }
        .refreshable { model.search(request); await model.waitForCurrentOperation() }
    }

    // MARK: Header and search

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find a study that fits.")
                .font(.system(.largeTitle, design: .serif, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("Search by condition, keyword, or city. Save the ones worth a closer look.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var searchBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.ink).accessibilityHidden(true)
            TextField("Condition, keyword, or city", text: $query)
                .focused($searchFocused)
                .submitLabel(.search).onSubmit(runSearch)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .accessibilityIdentifier("searchField")
            if !query.isEmpty {
                Button { query = ""; model.search(request) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }.accessibilityLabel("Clear search")
            }
            Button(action: runSearch) {
                Image(systemName: "arrow.right").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(Palette.teal, in: Circle())
            }
            .accessibilityLabel("Find studies").accessibilityIdentifier("searchButton")
        }
        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
        .surface(radius: 18)
    }

    private func runSearch() {
        searchFocused = false
        model.search(request)
    }

    // MARK: Filters

    private var filterRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        filters.recruitingOnly.toggle()
                        model.search(request)
                    } label: {
                        FilterChip(title: "Recruiting", icon: filters.recruitingOnly ? "checkmark" : "circle.fill", isOn: filters.recruitingOnly)
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("recruitingChip")
                    .accessibilityAddTraits(filters.recruitingOnly ? .isSelected : [])

                    Menu {
                        Picker("Phase", selection: Binding(get: { filters.phase }, set: { filters.phase = $0; model.search(request) })) {
                            Text("Any phase").tag(Optional<TrialPhase>.none)
                            ForEach(TrialPhase.allCases.filter { $0 != .unknown }, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                        }
                    } label: {
                        FilterChip(title: filters.phase?.rawValue ?? "Phase", icon: "chart.bar.xaxis", isOn: filters.phase != nil)
                    }
                    .accessibilityIdentifier("phaseChip")

                    Button { showFilters = true } label: {
                        FilterChip(title: filters.age.map { "Age \($0)" } ?? "Age", icon: "person", isOn: filters.age != nil)
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("ageChip")
                }
            }
            if filters.activeFilterCount > 0 {
                HStack {
                    Text(filters.activeFilterCount == 1 ? "1 filter applied" : "\(filters.activeFilterCount) filters applied")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear filters") { filters = SearchRequest(); model.search(request) }.font(.caption)
                }
            }
        }
    }

    private var topics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { topic in
                        Button { query = topic; runSearch() } label: {
                            Text(topic).font(.subheadline.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 9)
                                .background(.background, in: Capsule())
                                .overlay(Capsule().strokeBorder(.primary.opacity(0.1)))
                        }.buttonStyle(.plain).foregroundStyle(Palette.ink)
                    }
                }
            }
        }
    }

    // MARK: Results

    @ViewBuilder private var results: some View {
        switch model.state {
        case .idle, .loading:
            loading
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t load studies", systemImage: "wifi.exclamationmark")
            } description: { Text(message) } actions: {
                Button("Try again") { model.retry() }.buttonStyle(.borderedProminent).tint(Palette.teal).accessibilityIdentifier("retryButton")
            }
        case .loaded:
            if model.trials.isEmpty {
                ContentUnavailableView {
                    Label("No studies found", systemImage: "magnifyingglass")
                } description: { Text("Try a broader term or remove a filter.") }
                actions: {
                    Button("Reset search") { query = ""; filters = SearchRequest(); model.search(request) }
                }.accessibilityIdentifier("emptyState")
            } else {
                resultList
            }
        }
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: 14) {
            SlowLoadingHint(isLive: !isDemo) { model.cancel() }
            ForEach(0..<2, id: \.self) { _ in TrialCardSkeleton() }
        }.accessibilityIdentifier("loadingState")
    }

    private var resultList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(summaryLine).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            LazyVStack(spacing: 14) {
                ForEach(model.trials) { trial in
                    NavigationLink { LoadedTrialDetailView(trial: trial, service: service) } label: {
                        TrialCard(trial: trial, saved: saved.contains { $0.trialID == trial.id })
                    }.buttonStyle(.plain).accessibilityIdentifier("trial-\(trial.id)")
                }
            }
            if let error = model.pageError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            if model.nextOffset != nil {
                Button { model.loadMore() } label: {
                    HStack { if model.isLoadingMore { ProgressView() }; Text(model.pageError == nil ? "Show more studies" : "Retry loading more") }
                        .frame(maxWidth: .infinity).padding(8)
                }.buttonStyle(.bordered).tint(Palette.teal).disabled(model.isLoadingMore).accessibilityIdentifier("loadMoreButton")
            }
            EligibilityNote().padding(.top, 6)
            if isDemo { DemoNotice() }
        }
    }

    private var summaryLine: String {
        let count = model.total == 1 ? "1 study" : "\(model.total) studies"
        if model.request.query.isEmpty { return isDemo ? "\(count) · Demo catalog" : "\(count) · Top-ranked matches" }
        return isDemo ? "\(count) for “\(model.request.query)”" : "\(count) for “\(model.request.query)” · Top-ranked"
    }
}

/// Explains long waits instead of showing a bare spinner, and lets people stop a slow search.
private struct SlowLoadingHint: View {
    let isLive: Bool
    let cancel: () -> Void
    @State private var slow = false
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text(slow ? "Still searching…" : "Finding studies…").font(.subheadline.weight(.semibold))
                if slow {
                    Text(isLive ? "Ranking can take a minute on a live server." : "This is taking longer than usual.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if slow { Button("Cancel", action: cancel).font(.subheadline).accessibilityIdentifier("cancelSearchButton") }
        }
        .padding(.vertical, 4)
        .task {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { withAnimation { slow = true } }
        }
    }
}
