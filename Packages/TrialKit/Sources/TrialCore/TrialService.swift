import Foundation

public protocol TrialService: Sendable {
    func search(_ request: SearchRequest, offset: Int, limit: Int) async throws -> SearchPage
    func detail(for trial: Trial) async throws -> Trial
}

public extension TrialService {
    func detail(for trial: Trial) async throws -> Trial { trial }
}

public enum DemoCatalog {
    public static func load() throws -> [Trial] {
        guard let url = Bundle.module.url(forResource: "trials", withExtension: "json") else {
            throw TrialServiceError.invalidFixture
        }
        let trials = try JSONDecoder().decode([TrialDetailDTO].self, from: Data(contentsOf: url)).map { $0.trial() }
        guard !trials.isEmpty, Set(trials.map(\.id)).count == trials.count else {
            throw TrialServiceError.invalidFixture
        }
        return trials
    }
}

/// Deterministic keyword search, not a medical eligibility or relevance model.
public actor MockTrialService: TrialService {
    private let trials: [Trial]
    private var delay: Duration
    private var shouldFail = false

    public init(trials: [Trial], delay: Duration = .milliseconds(450)) {
        self.trials = trials
        self.delay = delay
    }

    public func configure(shouldFail: Bool, slow: Bool) {
        self.shouldFail = shouldFail
        delay = slow ? .seconds(2) : .milliseconds(450)
    }

    public func search(_ request: SearchRequest, offset: Int = 0, limit: Int = 6) async throws -> SearchPage {
        guard offset >= 0, (1...100).contains(limit) else { throw TrialServiceError.invalidPage }
        if let age = request.age, !(0...120).contains(age) { throw TrialServiceError.invalidAge }
        let failThisRequest = shouldFail
        try await Task.sleep(for: delay)
        try Task.checkCancellation()
        if failThisRequest { throw TrialServiceError.simulatedOffline }

        let tokens = request.query.folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let matches = trials.compactMap { trial -> (Trial, Int)? in
            guard !request.recruitingOnly || trial.status == .recruiting,
                  request.phase == nil || trial.phase == request.phase,
                  request.age.map({ trial.allows(age: $0) }) != false else { return nil }
            let title = trial.title.folded
            let condition = trial.condition.folded
            let text = ([trial.title, trial.condition, trial.summary, trial.location] + trial.keywords)
                .joined(separator: " ").folded
            guard tokens.allSatisfy({ text.contains($0) }) else { return nil }
            let score = tokens.reduce(0) { score, token in
                score + (condition.contains(token) ? 5 : 0) + (title.contains(token) ? 3 : 0) + 1
            }
            return (trial, score)
        }.sorted {
            $0.1 == $1.1 ? $0.0.id < $1.0.id : $0.1 > $1.1
        }.map(\.0)
        let start = min(offset, matches.count)
        let end = min(start + limit, matches.count)
        return SearchPage(trials: Array(matches[start..<end]), total: matches.count,
                          nextOffset: end < matches.count ? end : nil)
    }
}

private extension String {
    var folded: String { folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
}
