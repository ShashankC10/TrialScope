import Foundation

public enum APIError: LocalizedError, Sendable {
    case configuration, status(Int), invalidResponse
    public var errorDescription: String? {
        switch self {
        case .configuration: "Set API_BASE_URL to your server’s HTTP or HTTPS base URL in the Run scheme environment."
        case .status(let code): "The server returned HTTP \(code). Please try again."
        case .invalidResponse: "The server returned an unexpected response."
        }
    }
}

public enum ServiceConfiguration: Equatable, Sendable {
    case mock, api(URL)
    public static func resolve(environment: [String: String], arguments: [String]) throws -> Self {
        // Tests must never depend on a developer’s server configuration.
        if arguments.contains("--uitesting") || environment["TRIALSCOPE_USE_MOCKS"] == "1" { return .mock }
        guard let value = environment["API_BASE_URL"],
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw APIError.configuration
        }
        return .api(url)
    }
}

/// Matches RankRequest in backend/api/main.py. No invented patient attributes.
struct RankRequestDTO: Encodable {
    struct Profile: Encodable { let age: Int? }
    let profile: Profile
    let query: String
    let phase: String?
    let overall_status: String?
    init(_ request: SearchRequest) {
        profile = Profile(age: request.age)
        query = request.query
        phase = request.phase?.apiValue
        overall_status = request.recruitingOnly ? "RECRUITING" : nil
    }
}

extension TrialPhase {
    var apiValue: String? {
        switch self {
        case .phase1: "PHASE1"
        case .phase2: "PHASE2"
        case .phase3: "PHASE3"
        // Observational is a study_type, not a phase filter in this API.
        case .observational, .unknown: nil
        }
    }
}

struct SearchResponseDTO: Decodable {
    let total: Int
    let page: Int
    let size: Int
    let hits: [TrialHitDTO]
    let candidate_total: Int?
    let truncated: Bool?
}

struct TrialHitDTO: Decodable {
    let nct_id: String
    let title: String?
    let brief_summary: String?
    let phase: String?
    let overall_status: String?
    let conditions: [String]?
    let study_type: String?
    let locations: [String]?
    let min_age_years: Double?
    let max_age_years: Double?
    let eligibility_criteria_raw: String?

    func trial() -> Trial {
        mapTrial(id: nct_id, title: title, summary: brief_summary, conditions: conditions,
                 phase: phase, status: overall_status, studyType: study_type,
                 locations: locations ?? [], minimum: min_age_years, maximum: max_age_years,
                 inclusion: nil, exclusion: nil, rawCriteria: eligibility_criteria_raw, updated: nil)
    }
}

struct TrialDetailDTO: Decodable {
    struct Location: Decodable {
        let facility_name: String?
        let city: String?
        let state: String?
        let country: String?
        var text: String { [facility_name, city, state, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") }
    }
    let nct_id: String
    let title: String?
    let official_title: String?
    let brief_summary: String?
    let detailed_description: String?
    let conditions: [String]?
    let study_type: String?
    let phase: String?
    let overall_status: String?
    let min_age_years: Double?
    let max_age_years: Double?
    let last_updated: String?
    let locations: [Location]?
    let criteria_inclusion: String?
    let criteria_exclusion: String?
    let eligibility_criteria_raw: String?

    func trial() -> Trial {
        mapTrial(id: nct_id, title: firstNonempty(title, official_title), summary: firstNonempty(detailed_description, brief_summary),
                 conditions: conditions, phase: phase, status: overall_status, studyType: study_type,
                 locations: locations?.map(\.text) ?? [], minimum: min_age_years,
                 maximum: max_age_years, inclusion: criteria_inclusion, exclusion: criteria_exclusion,
                 rawCriteria: eligibility_criteria_raw, updated: last_updated)
    }
}

private func firstNonempty(_ values: String?...) -> String? {
    values.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
}

private func mapTrial(id: String, title: String?, summary: String?, conditions: [String]?,
                      phase: String?, status: String?, studyType: String?, locations: [String],
                      minimum: Double?, maximum: Double?, inclusion: String?, exclusion: String?,
                      rawCriteria: String?, updated: String?) -> Trial {
    func text(_ value: String?, fallback: String = "Not provided") -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return fallback }
        return value
    }
    let phaseValue = phase?.uppercased().replacingOccurrences(of: " ", with: "")
    let mappedPhase: TrialPhase = switch phaseValue {
    case "PHASE1": .phase1
    case "PHASE2": .phase2
    case "PHASE3": .phase3
    default: studyType?.uppercased() == "OBSERVATIONAL" ? .observational : .unknown
    }
    let mappedStatus: RecruitmentStatus = switch status?.uppercased().replacingOccurrences(of: " ", with: "_") {
    case "RECRUITING": .recruiting
    case "NOT_YET_RECRUITING": .notYetRecruiting
    case "ACTIVE,_NOT_RECRUITING", "ACTIVE_NOT_RECRUITING": .active
    default: .unknown
    }
    var seenSites = Set<String>()
    let sites = locations.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && seenSites.insert($0).inserted }
    let conditionNames = (conditions ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    var trial = Trial(id: id, title: text(title, fallback: id), condition: text(conditionNames.joined(separator: ", ")),
                      summary: text(summary), sponsor: "Not provided by the API", city: sites.first ?? "Not provided", state: "",
                      phase: mappedPhase, status: mappedStatus,
                      minimumAge: clampedAge(minimum).map { Int($0.rounded(.up)) } ?? 0,
                      maximumAge: clampedAge(maximum).map { Int($0.rounded(.down)) },
                      inclusion: [text(inclusion)], exclusion: [text(exclusion)], keywords: conditionNames,
                      updated: text(updated))
    trial.apiPhase = mappedPhase == .unknown ? text(phase) : mappedPhase.rawValue
    trial.apiStatus = mappedStatus == .unknown ? text(status) : mappedStatus.rawValue
    trial.apiAgeDescription = ageText(minimum, maximum)
    trial.apiLocations = sites
    trial.rawEligibility = rawCriteria
    return trial
}

/// Registry values may be NaN, infinite, or absurd. Never convert an unbounded Double to Int.
private func clampedAge(_ value: Double?) -> Double? {
    guard let value, value.isFinite else { return nil }
    return min(max(value, 0), 10000)
}

/// "18–65 years", "6+ months", "Up to 17 years", or "Not specified".
private func ageText(_ minimum: Double?, _ maximum: Double?) -> String {
    func unit(_ value: Double) -> String { value > 0 && value < 1 ? "months" : "years" }
    func number(_ value: Double) -> String {
        if value > 0 && value < 1 { return String(max(Int((value * 12).rounded()), 1)) }
        return value == value.rounded() ? String(Int(value)) : String(value)
    }
    // Registry values may be malformed. Never convert unbounded Doubles to Int.
    let low = minimum.flatMap { $0.isFinite && (0...10000).contains($0) ? $0 : nil }
    let high = maximum.flatMap { $0.isFinite && (0...10000).contains($0) ? $0 : nil }
    switch (low, high) {
    case let (low?, high?):
        if unit(low) == unit(high) { return "\(number(low))–\(number(high)) \(unit(high))" }
        return "\(number(low)) \(unit(low))–\(number(high)) \(unit(high))"
    case let (low?, nil): return "\(number(low))+ \(unit(low))"
    case let (nil, high?): return "Up to \(number(high)) \(unit(high))"
    case (nil, nil): return "Not specified"
    }
}

public actor APITrialService: TrialService {
    private let baseURL: URL
    private let session: URLSession
    private var cachedRequest: SearchRequest?
    private var cachedTrials: [Trial] = []
    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func search(_ request: SearchRequest, offset: Int, limit: Int) async throws -> SearchPage {
        guard offset >= 0, (1...100).contains(limit) else { throw TrialServiceError.invalidPage }
        if let age = request.age, !(0...120).contains(age) { throw TrialServiceError.invalidAge }
        // The server currently returns one top-20 candidate window, not arbitrary pages.
        if offset == 0 || cachedRequest != request {
            var urlRequest = URLRequest(url: baseURL.appendingPathComponent("rank"))
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(RankRequestDTO(request))
            let response: SearchResponseDTO = try await send(urlRequest)
            guard response.total >= 0, response.page == 1, response.size > 0,
                  Set(response.hits.map(\.nct_id)).count == response.hits.count else { throw APIError.invalidResponse }
            try Task.checkCancellation()
            cachedRequest = request
            cachedTrials = response.hits.map { $0.trial() }
            // The API has no study_type filter. This narrows only the returned window.
            if request.phase == .observational { cachedTrials = cachedTrials.filter { $0.phase == .observational } }
        }
        let start = min(offset, cachedTrials.count)
        let end = min(start + limit, cachedTrials.count)
        return SearchPage(trials: Array(cachedTrials[start..<end]), total: cachedTrials.count,
                          nextOffset: end < cachedTrials.count ? end : nil)
    }

    public func detail(for trial: Trial) async throws -> Trial {
        guard !trial.id.isEmpty, trial.id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { throw APIError.invalidResponse }
        let request = URLRequest(url: baseURL.appendingPathComponent("trials").appendingPathComponent(trial.id))
        let response: TrialDetailDTO = try await send(request)
        guard response.nct_id == trial.id else { throw APIError.invalidResponse }
        return response.trial()
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        var request = request
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw APIError.status(response.statusCode) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.invalidResponse }
    }
}
