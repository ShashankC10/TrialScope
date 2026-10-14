import Foundation
import Testing
@testable import TrialCore

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    // Only this serialized suite accesses the handler; each request completes before replacement.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, body) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private func bodyData(_ request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open(); defer { stream.close() }
    var data = Data()
    var bytes = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let count = stream.read(&bytes, maxLength: bytes.count)
        if count <= 0 { break }
        data.append(contentsOf: bytes.prefix(count))
    }
    return data
}

@Suite("API contract", .serialized)
struct APIContractTests {
    private func service() -> APITrialService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return APITrialService(baseURL: URL(string: "https://contract.invalid/api")!, session: URLSession(configuration: configuration))
    }
    private func response(count: Int = 8) throws -> Data {
        let hits: [[String: Any]] = (0..<count).map {
            ["nct_id": "NCT0000000\($0)", "title": "Contract study \($0)", "brief_summary": NSNull(),
             "phase": "PHASE2", "overall_status": "RECRUITING", "conditions": ["Breast Cancer"],
             "locations": ["Boston, Massachusetts, United States"], "score": 0.8,
             "min_age_years": 0.5, "max_age_years": NSNull(), "parsed_criteria": ["example": true]]
        }
        return try JSONSerialization.data(withJSONObject: ["total": 500, "page": 1, "size": 20,
                                                            "hits": hits, "candidate_total": 500, "truncated": true])
    }

    @Test func configurationRequiresURLAndTestsOverrideIt() throws {
        #expect(throws: APIError.self) { try ServiceConfiguration.resolve(environment: [:], arguments: []) }
        for url in ["file:///tmp/api", "localhost:8000", "https://user:secret@example.com", "https://example.com?q=secret"] {
            #expect(throws: APIError.self) { try ServiceConfiguration.resolve(environment: ["API_BASE_URL": url], arguments: []) }
        }
        #expect(try ServiceConfiguration.resolve(environment: ["API_BASE_URL": "bad"], arguments: ["--uitesting"]) == .mock)
        #expect(try ServiceConfiguration.resolve(environment: ["TRIALSCOPE_USE_MOCKS": "1"], arguments: []) == .mock)
        #expect(try ServiceConfiguration.resolve(environment: ["API_BASE_URL": "http://localhost:8000"], arguments: []) == .api(URL(string: "http://localhost:8000")!))
    }

    @Test func rankEncodesFiltersAndPaginatesOnlyReturnedWindow() async throws {
        let data = try response()
        StubProtocol.handler = { request in
            #expect(request.url?.path == "/api/rank")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let json = try #require(JSONSerialization.jsonObject(with: bodyData(request)) as? [String: Any])
            #expect(json["query"] as? String == "breast cancer")
            #expect(json["phase"] as? String == "PHASE2")
            #expect(json["overall_status"] as? String == "RECRUITING")
            #expect((json["profile"] as? [String: Any])?["age"] as? Int == 35)
            return (200, data)
        }
        let service = service()
        let query = SearchRequest(query: "breast cancer", recruitingOnly: true, phase: .phase2, age: 35)
        let page = try await service.search(query, offset: 0, limit: 6)
        #expect(page.total == 8) // Candidate total is not the number of retrievable results.
        #expect(page.nextOffset == 6)
        #expect(page.trials.first?.summary == "Not provided")
        #expect(page.trials.first?.ageDescription == "6+ months")
        StubProtocol.handler = { _ in Issue.record("Pagination should use the fetched window"); return (500, Data()) }
        let next = try await service.search(query, offset: 6, limit: 6)
        #expect(next.trials.count == 2)
        #expect(next.nextOffset == nil)
    }

    @Test func refreshFetchesAgainAndEmptyResultsStopPaging() async throws {
        let data = try response()
        StubProtocol.handler = { _ in (200, data) }
        let service = service()
        _ = try await service.search(SearchRequest(), offset: 0, limit: 6)
        let empty = try response(count: 0)
        StubProtocol.handler = { _ in (200, empty) }
        let refreshed = try await service.search(SearchRequest(), offset: 0, limit: 6)
        #expect(refreshed.total == 0)
        #expect(refreshed.nextOffset == nil)
    }

    @Test func detailDecodesStructuredLocationsAndUnknownValues() async throws {
        let data = Data(#"{"nct_id":"DEMO-001","official_title":"Official title","phase":"PHASE4","overall_status":"COMPLETED","conditions":[],"locations":[{"facility_name":"Research Center","city":"Boston","country":"USA"}],"criteria_inclusion":"First criterion\nSecond criterion","criteria_exclusion":null,"eligibility_criteria_raw":"Full criteria","last_updated":"2026-10-01"}"#.utf8)
        StubProtocol.handler = { request in
            #expect(request.url?.path == "/api/trials/DEMO-001")
            #expect(request.httpMethod == "GET")
            return (200, data)
        }
        let detail = try await service().detail(for: DemoCatalog.load()[0])
        #expect(detail.title == "Official title")
        #expect(detail.location == "Research Center, Boston, USA")
        #expect(detail.phaseDescription == "PHASE4")
        #expect(detail.statusDescription == "COMPLETED")
        #expect(detail.status != .recruiting)
        #expect(detail.rawEligibility == "Full criteria")
        #expect(detail.exclusion == ["Not provided"])
        #expect(detail.ageDescription == "Not specified")
    }

    @Test func presentationFieldsAreReadable() async throws {
        let hit: [String: Any] = ["nct_id": "NCT00000001", "title": "Study", "phase": "PHASE1/PHASE2",
                                  "overall_status": "RECRUITING", "conditions": ["Asthma", " Eczema ", ""],
                                  "locations": ["Boston, MA", "Boston, MA", "Austin, TX", "  "],
                                  "min_age_years": 18.0, "max_age_years": 65.0]
        let body = try JSONSerialization.data(withJSONObject: ["total": 1, "page": 1, "size": 20, "hits": [hit]])
        StubProtocol.handler = { _ in (200, body) }
        let trial = try #require(try await service().search(SearchRequest(), offset: 0, limit: 6).trials.first)
        #expect(trial.ageDescription == "18–65 years")
        #expect(trial.sites == ["Boston, MA", "Austin, TX"])
        #expect(trial.location == "Boston, MA")
        #expect(trial.additionalSiteCount == 1)
        #expect(trial.conditionList == ["Asthma", "Eczema"])
        #expect(trial.primaryCondition == "Asthma")
        #expect(trial.additionalConditionCount == 1)
        #expect(trial.hasSummary == false)
    }

    @Test func blankDetailFieldsUseAvailableFallbacks() async throws {
        let data = Data(#"{"nct_id":"DEMO-001","title":"  ","official_title":"Official fallback","detailed_description":"\n  ","brief_summary":"Brief fallback"}"#.utf8)
        StubProtocol.handler = { _ in (200, data) }
        let detail = try await service().detail(for: DemoCatalog.load()[0])
        #expect(detail.title == "Official fallback")
        #expect(detail.summary == "Brief fallback")
    }

    @Test func malformedAgeValuesDoNotCrashPresentation() async throws {
        for value in ["1e100", "-10"] {
            let data = Data("{\"nct_id\":\"DEMO-001\",\"min_age_years\":\(value),\"max_age_years\":\(value)}".utf8)
            StubProtocol.handler = { _ in (200, data) }
            let detail = try await service().detail(for: DemoCatalog.load()[0])
            #expect(detail.ageDescription == "Not specified")
        }
    }

    @Test func nonFiniteAgesDoNotCrashMapping() throws {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        for (low, high) in [("NaN", "NaN"), ("\"-Infinity\"", "\"Infinity\""), ("1e308", "-1e308")] {
            let lowValue = low == "NaN" ? "\"NaN\"" : low
            let highValue = high == "NaN" ? "\"NaN\"" : high
            let json = #"{"nct_id":"NCT00000002","title":"Edge","min_age_years":\#(lowValue),"max_age_years":\#(highValue)}"#
            let trial = try decoder.decode(TrialDetailDTO.self, from: Data(json.utf8)).trial()
            #expect(trial.minimumAge >= 0)
            #expect(trial.ageDescription.isEmpty == false)
        }
    }

    @Test func rejectsMismatchedDetailAndMalformedResponses() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"nct_id":"wrong"}"#.utf8)) }
        await #expect(throws: APIError.self) { try await service().detail(for: DemoCatalog.load()[0]) }
        StubProtocol.handler = { _ in (200, Data("not json".utf8)) }
        await #expect(throws: APIError.self) { try await service().search(SearchRequest(), offset: 0, limit: 6) }
    }

    @Test func httpErrorsAndTimeoutsReachCallerWithoutMockFallback() async throws {
        for status in [404, 422, 503] {
            StubProtocol.handler = { _ in (status, Data(#"{"detail":"internal server information"}"#.utf8)) }
            do {
                _ = try await service().search(SearchRequest(), offset: 0, limit: 6)
                Issue.record("Expected HTTP error")
            } catch APIError.status(let actual) { #expect(actual == status) }
        }
        StubProtocol.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: URLError.self) { try await service().search(SearchRequest(), offset: 0, limit: 6) }
    }

    @Test func cancelledRequestDoesNotReturnResults() async throws {
        StubProtocol.handler = { _ in throw URLError(.cancelled) }
        let service = service()
        let task = Task { try await service.search(SearchRequest(), offset: 0, limit: 6) }
        task.cancel()
        do { _ = try await task.value; Issue.record("Expected cancellation") } catch {}
    }
}
