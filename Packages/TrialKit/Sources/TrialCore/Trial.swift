import Foundation

public enum RecruitmentStatus: String, Codable, CaseIterable, Sendable {
    case recruiting = "Recruiting"
    case notYetRecruiting = "Not yet recruiting"
    case active = "Active, not recruiting"
}

public enum TrialPhase: String, Codable, CaseIterable, Sendable {
    case phase1 = "Phase 1"
    case phase2 = "Phase 2"
    case phase3 = "Phase 3"
    case observational = "Observational"
}

public struct Trial: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let condition: String
    public let summary: String
    public let sponsor: String
    public let city: String
    public let state: String
    public let phase: TrialPhase
    public let status: RecruitmentStatus
    public let minimumAge: Int
    public let maximumAge: Int?
    public let inclusion: [String]
    public let exclusion: [String]
    public let keywords: [String]
    public let updated: String

    public var location: String { "\(city), \(state)" }
    public var ageDescription: String {
        if let maximumAge { return "\(minimumAge)–\(maximumAge) years" }
        return "\(minimumAge)+ years"
    }
    public func allows(age: Int) -> Bool {
        age >= minimumAge && maximumAge.map { age <= $0 } != false
    }
}

public struct SearchRequest: Equatable, Sendable {
    public var query: String
    public var recruitingOnly: Bool
    public var phase: TrialPhase?
    public var age: Int?

    public init(query: String = "", recruitingOnly: Bool = false,
                phase: TrialPhase? = nil, age: Int? = nil) {
        self.query = query
        self.recruitingOnly = recruitingOnly
        self.phase = phase
        self.age = age
    }
    public var activeFilterCount: Int {
        (recruitingOnly ? 1 : 0) + (phase == nil ? 0 : 1) + (age == nil ? 0 : 1)
    }
}

public struct SearchPage: Sendable {
    public let trials: [Trial]
    public let total: Int
    public let nextOffset: Int?
    public init(trials: [Trial], total: Int, nextOffset: Int?) {
        self.trials = trials
        self.total = total
        self.nextOffset = nextOffset
    }
}

public enum TrialServiceError: LocalizedError, Sendable {
    case simulatedOffline
    case invalidPage
    case invalidAge
    case invalidFixture

    public var errorDescription: String? {
        switch self {
        case .simulatedOffline: "The demo service is unavailable. Turn off simulated failure in Settings, then try again."
        case .invalidPage: "The requested page is invalid."
        case .invalidAge: "Enter an age between 0 and 120."
        case .invalidFixture: "The bundled demo catalog could not be loaded."
        }
    }
}
