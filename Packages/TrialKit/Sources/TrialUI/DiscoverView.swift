import SwiftUI
import SwiftData
import TrialCore

struct DiscoverView: View {
    @Bindable var model: SearchModel
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if model.request.query.isEmpty && model.request.activeFilterCount == 0 { hero }
                searchBox
                if query.isEmpty && filters.activeFilterCount == 0 { topics }
                results
                DemoNotice()
            }.padding(20).readableWidth()
        }
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("A LITTLE CLARITY. A NEXT STEP.", systemImage: "sparkle")
                    .font(.caption2.weight(.bold)).tracking(1)
                Spacer(minLength: 0)
            }.foregroundStyle(Palette.mint)
            Text("Research,\nwithin reach.")
                .font(.system(.largeTitle, design: .serif, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("Explore studies. Understand the details.\nKeep the possibilities that matter to you.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").foregroundStyle(Palette.coral)
                Text("Your search starts here").font(.caption.weight(.medium))
            }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(26)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 28).fill(Palette.teal.gradient)
                .overlay(alignment: .trailing) {
                    Image(systemName: "circle.hexagongrid.fill").font(.system(size: 160))
                        .foregroundStyle(.white.opacity(0.04)).offset(x: 35, y: 30).accessibilityHidden(true)
                }.clipShape(RoundedRectangle(cornerRadius: 28))
        }
    }

    private var searchBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.ink)
                TextField("Condition, keyword, or city", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search).onSubmit { searchFocused = false; model.search(request) }
                    .accessibilityIdentifier("searchField")
                if !query.isEmpty {
                    Button { query = ""; model.search(request) } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 16))
            Button { searchFocused = false; model.search(request) } label: {
                HStack { Text("Find studies"); Spacer(); Image(systemName: "arrow.right") }
                    .font(.headline).padding(8).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(Palette.teal).controlSize(.large).accessibilityIdentifier("searchButton")
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
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPLORE A TOPIC").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestions, id: \.self) { topic in
                        Button { query = topic; model.search(request) } label: {
                            Text(topic).font(.subheadline.weight(.medium)).padding(.horizontal, 15).padding(.vertical, 11)
                                .background(Palette.teal.opacity(0.08), in: Capsule())
                        }.buttonStyle(.plain).foregroundStyle(Palette.ink)
                    }
                }
            }
        }
    }

    @ViewBuilder private var results: some View {
        switch model.state {
        case .idle, .loading:
            VStack(spacing: 16) {
                ProgressView()
                Text("Finding possibilities…").font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(40).accessibilityIdentifier("loadingState")
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
                } description: { Text("Try a broader term or remove a filter. This demo includes a small fictional catalog.") }
                actions: {
                    Button("Reset search") { query = ""; filters = SearchRequest(); model.search(request) }
                }.accessibilityIdentifier("emptyState")
            } else {
                SectionTitle(title: model.request.query.isEmpty ? "Explore studies" : "Search results",
                             subtitle: "\(model.total) demo studies · Matches are not confirmed eligibility")
                LazyVStack(spacing: 16) {
                    ForEach(model.trials) { trial in
                        NavigationLink { TrialDetailView(trial: trial) } label: {
                            TrialCard(trial: trial, saved: saved.contains { $0.trialID == trial.id })
                        }.buttonStyle(.plain).accessibilityIdentifier("trial-\(trial.id)")
                    }
                }
                if let error = model.pageError {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
                if model.nextOffset != nil {
                    Button { model.loadMore() } label: {
                        HStack { if model.isLoadingMore { ProgressView() }; Text(model.pageError == nil ? "Load more studies" : "Retry loading more") }
                            .frame(maxWidth: .infinity).padding(8)
                    }.buttonStyle(.bordered).disabled(model.isLoadingMore).accessibilityIdentifier("loadMoreButton")
                }
            }
        }
    }
}
