import Foundation
import SwiftData
import Testing
@testable import TrialCore

@Suite("Mock catalog and search")
struct MockSearchTests {
    @Test func fixtureIntegrity() throws {
        let trials = try DemoCatalog.load()
        #expect(trials.count == 18)
        #expect(Set(trials.map(\.id)).count == trials.count)
        #expect(trials.allSatisfy { $0.id.hasPrefix("DEMO-") && !$0.inclusion.isEmpty && !$0.exclusion.isEmpty })
        #expect(trials.allSatisfy { $0.maximumAge.map { $0 >= 0 } ?? true })
    }

    @Test func normalizationAndAllTokenMatching() async throws {
        let service = MockTrialService(trials: try DemoCatalog.load(), delay: .zero)
        let page = try await service.search(SearchRequest(query: "  BREAST   cáncer  "), limit: 100)
        #expect(page.total == 3)
        #expect(page.trials.allSatisfy { $0.condition == "Breast Cancer" })
        let none = try await service.search(SearchRequest(query: "breast migraine"))
        #expect(none.total == 0)
    }

    @Test func filtersComposeAndRespectAgeBoundaries() async throws {
        let service = MockTrialService(trials: try DemoCatalog.load(), delay: .zero)
        let request = SearchRequest(query: "breast", recruitingOnly: true, phase: .phase2, age: 75)
        let page = try await service.search(request)
        #expect(page.trials.map(\.id) == ["DEMO-001"])
        var older = request
        older.age = 76
        #expect(try await service.search(older).total == 0)
        let pediatric = try await service.search(SearchRequest(query: "diabetes", age: 8))
        #expect(pediatric.trials.map(\.id) == ["DEMO-018"])
    }

    @Test func paginationHasNoGapsOrDuplicates() async throws {
        let service = MockTrialService(trials: try DemoCatalog.load(), delay: .zero)
        var ids: [String] = []
        var offset: Int? = 0
        while let current = offset {
            let page = try await service.search(SearchRequest(), offset: current, limit: 5)
            #expect(page.total == 18)
            ids += page.trials.map(\.id)
            offset = page.nextOffset
        }
        #expect(ids.count == 18)
        #expect(Set(ids).count == 18)
        #expect(try await service.search(SearchRequest(), offset: 100).trials.isEmpty)
    }

    @Test func invalidInputsFailExplicitly() async throws {
        let service = MockTrialService(trials: try DemoCatalog.load(), delay: .zero)
        await #expect(throws: TrialServiceError.self) { try await service.search(SearchRequest(), offset: -1) }
        await #expect(throws: TrialServiceError.self) { try await service.search(SearchRequest(), limit: 0) }
        await #expect(throws: TrialServiceError.self) { try await service.search(SearchRequest(age: 121)) }
    }

    @Test func cancellationStopsSlowRequest() async throws {
        let service = MockTrialService(trials: try DemoCatalog.load(), delay: .seconds(10))
        let task = Task { try await service.search(SearchRequest()) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}

private actor OutOfOrderService: TrialService {
    let trials: [Trial]
    init(trials: [Trial]) { self.trials = trials }
    func search(_ request: SearchRequest, offset: Int, limit: Int) async throws -> SearchPage {
        // Intentionally ignores cancellation to simulate a callback-backed transport.
        if request.query == "old" {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) { continuation.resume() }
            }
            return SearchPage(trials: [trials[0]], total: 1, nextOffset: nil)
        }
        return SearchPage(trials: [trials[1]], total: 1, nextOffset: nil)
    }
}

@Suite("Search state") @MainActor
struct SearchStateTests {
    @Test func newerRequestWinsEvenIfOldServiceIgnoresCancellation() async throws {
        let model = SearchModel(service: OutOfOrderService(trials: try DemoCatalog.load()))
        model.search(SearchRequest(query: "old"))
        try await Task.sleep(for: .milliseconds(10))
        model.search(SearchRequest(query: "new"))
        await model.waitForCurrentOperation()
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.trials.map(\.id) == ["DEMO-002"])
        #expect(model.request.query == "new")
        #expect(model.state == .loaded)
    }

    @Test func failureRetryAndPaginationPreserveResults() async throws {
        let service = MockTrialService(trials: try DemoCatalog.load(), delay: .zero)
        let model = SearchModel(service: service)
        await service.configure(shouldFail: true, slow: false)
        model.search(SearchRequest())
        await model.waitForCurrentOperation()
        guard case .failed = model.state else { Issue.record("Expected failed state"); return }
        await service.configure(shouldFail: false, slow: false)
        model.retry()
        await model.waitForCurrentOperation()
        #expect(model.trials.count == 6)
        await service.configure(shouldFail: true, slow: false)
        model.loadMore()
        await model.waitForCurrentOperation()
        #expect(model.trials.count == 6)
        #expect(model.pageError != nil)
        await service.configure(shouldFail: false, slow: false)
        model.loadMore()
        model.loadMore() // Repeated taps must not duplicate a page.
        await model.waitForCurrentOperation()
        #expect(model.trials.count == 12)
        #expect(model.pageError == nil)
    }
}

@Suite("SwiftData bookmarks") @MainActor
struct PersistenceTests {
    @Test func saveIsIdempotentAndNotesPersistAcrossContexts() throws {
        let container = try TrialStore.container(inMemory: true)
        let context = ModelContext(container)
        let trial = try DemoCatalog.load()[0]
        try TrialStore.save(trial, in: context)
        try TrialStore.save(trial, in: context)
        let records = try context.fetch(FetchDescriptor<SavedTrial>())
        #expect(records.count == 1)
        let saved = try #require(records.first)
        try TrialStore.updateNotes("Ask about the visit schedule.", for: saved, in: context)
        let otherContext = ModelContext(container)
        let reloaded = try #require(otherContext.fetch(FetchDescriptor<SavedTrial>()).first)
        #expect(reloaded.trial == trial)
        #expect(reloaded.notes == "Ask about the visit schedule.")
        try TrialStore.remove(id: trial.id, in: otherContext)
        #expect(try otherContext.fetchCount(FetchDescriptor<SavedTrial>()) == 0)
    }

    @Test func corruptSnapshotDoesNotCrash() throws {
        let saved = try SavedTrial(trial: DemoCatalog.load()[0])
        saved.snapshot = Data("not json".utf8)
        #expect(saved.trial == nil)
    }

    @Test func diskStoreSurvivesContainerRecreation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("bookmarks.store")
        let trial = try DemoCatalog.load()[0]
        func write() throws {
            let container = try ModelContainer(for: SavedTrial.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            try TrialStore.save(trial, in: ModelContext(container))
        }
        try write()
        let reopened = try ModelContainer(for: SavedTrial.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let loaded = try ModelContext(reopened).fetch(FetchDescriptor<SavedTrial>())
        #expect(loaded.first?.trial == trial)
    }
}
