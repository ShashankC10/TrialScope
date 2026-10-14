import Foundation

public enum RecruitmentStatus: String, Codable, CaseIterable, Sendable {
    case recruiting = "Recruiting"
    case notYetRecruiting = "Not yet recruiting"
    case active = "Active, not recruiting"
    case unknown = "Not provided"
}

public enum TrialPhase: String, Codable, CaseIterable, Sendable {
    case phase1 = "Phase 1"
    case phase2 = "Phase 2"
    case phase3 = "Phase 3"
    case observational = "Observational"
    case unknown = "Not provided"
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

    // Optional metadata keeps previously saved JSON snapshots decodable.
    public var apiPhase: String?
    public var apiStatus: String?
    public var apiAgeDescription: String?
    public var rawEligibility: String?
    public var apiLocations: [String]?
    public var isDemo: Bool { id.hasPrefix("DEMO-") }
    public var phaseDescription: String { apiPhase ?? phase.rawValue }
    public var statusDescription: String { apiStatus ?? status.rawValue }
    /// Every known study site. Demo studies have one; real registry entries can have dozens.
    public var sites: [String] {
        if let apiLocations, !apiLocations.isEmpty { return apiLocations }
        let single = [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
        return single.isEmpty ? [] : [single]
    }
    public var location: String { sites.first ?? "Not provided" }
    public var additionalSiteCount: Int { max(sites.count - 1, 0) }
    /// `keywords` doubles as the condition list when it reproduces `condition`; older snapshots fall back to one entry.
    public var conditionList: [String] {
        !keywords.isEmpty && keywords.joined(separator: ", ") == condition ? keywords : [condition]
    }
    public var primaryCondition: String { conditionList.first ?? condition }
    public var additionalConditionCount: Int { max(conditionList.count - 1, 0) }
    public var hasSummary: Bool {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "Not provided"
    }
    public var ageDescription: String {
        if let apiAgeDescription { return apiAgeDescription }
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
