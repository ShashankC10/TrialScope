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
            case .failure:
                ContentUnavailableView("TrialScope couldn’t start", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("The local catalog or saved data couldn’t be opened. Close and reopen the app. Your saved data has not been deleted."))
            }
        }
    }
}

@MainActor
private struct AppDependencies {
    let service: MockTrialService
    let container: ModelContainer
    init() throws {
        service = MockTrialService(trials: try DemoCatalog.load())
        // UI tests use a disposable store. Normal launches persist locally.
        container = try TrialStore.container(inMemory: ProcessInfo.processInfo.arguments.contains("--uitesting"))
    }
}
