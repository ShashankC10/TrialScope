import Foundation
import Observation

@MainActor @Observable
public final class SearchModel {
    public enum State: Equatable { case idle, loading, loaded, failed(String) }
    public private(set) var state: State = .idle
    public private(set) var trials: [Trial] = []
    public private(set) var total = 0
    public private(set) var nextOffset: Int?
    public private(set) var isLoadingMore = false
    public private(set) var pageError: String?
    public private(set) var request = SearchRequest()
    @ObservationIgnored private let service: any TrialService
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(service: any TrialService) { self.service = service }

    public func search(_ request: SearchRequest) {
        task?.cancel()
        generation = UUID()
        let current = generation
        self.request = request
        state = .loading
        trials = []
        total = 0
        nextOffset = nil
        isLoadingMore = false
        pageError = nil
        task = Task { [weak self, service] in
            do {
                let page = try await service.search(request, offset: 0, limit: 6)
                guard let self, self.generation == current, !Task.isCancelled else { return }
                self.trials = page.trials
                self.total = page.total
                self.nextOffset = page.nextOffset
                self.state = .loaded
            } catch {
                guard let self, self.generation == current, !Task.isCancelled else { return }
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    public func loadMore() {
        guard let offset = nextOffset, !isLoadingMore, state == .loaded else { return }
        let current = generation
        let request = request
        isLoadingMore = true
        pageError = nil
        task = Task { [weak self, service] in
            do {
                let page = try await service.search(request, offset: offset, limit: 6)
                guard let self, self.generation == current, !Task.isCancelled else { return }
                let existing = Set(self.trials.map(\.id))
                self.trials += page.trials.filter { !existing.contains($0.id) }
                self.nextOffset = page.nextOffset
                self.isLoadingMore = false
            } catch {
                guard let self, self.generation == current, !Task.isCancelled else { return }
                self.pageError = error.localizedDescription
                self.isLoadingMore = false
            }
        }
    }

    public func retry() { search(request) }
    /// Allows deterministic tests and pull-to-refresh to wait for the current operation.
    public func waitForCurrentOperation() async { await task?.value }
}
