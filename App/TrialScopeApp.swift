import SwiftUI
import SwiftData
import TrialCore
import TrialUI

@main
struct TrialScopeApp: App {
    private let startup: Result<AppDependencies, Error>
    init() { startup = Result { try AppDependencies() } }
    var body: some Scene {
        WindowGroup {
            switch startup {
            case .success(let dependencies):
                TrialScopeRoot(service: dependencies.service).modelContainer(dependencies.container)
            case .failure(let error):
                ContentUnavailableView("TrialScope couldn’t start", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(error.localizedDescription))
            }
        }
    }
}

@MainActor
private struct AppDependencies {
    let service: any TrialService
    let container: ModelContainer
    init() throws {
        switch try ServiceConfiguration.resolve(environment: ProcessInfo.processInfo.environment,
                                                arguments: ProcessInfo.processInfo.arguments) {
        case .mock: service = MockTrialService(trials: try DemoCatalog.load())
        case .api(let url): service = APITrialService(baseURL: url)
        }
        // UI tests use a disposable store. Normal launches persist locally.
        container = try TrialStore.container(inMemory: ProcessInfo.processInfo.arguments.contains("--uitesting"))
    }
}
