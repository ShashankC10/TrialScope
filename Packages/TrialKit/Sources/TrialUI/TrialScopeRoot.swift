import SwiftUI
import SwiftData
import TrialCore

public struct TrialScopeRoot: View {
    @State private var model: SearchModel
    private let service: any TrialService
    @State private var selection = 0

    public init(service: any TrialService) {
        self.service = service
        _model = State(initialValue: SearchModel(service: service))
    }

    public var body: some View {
        TabView(selection: $selection) {
            NavigationStack { DiscoverView(model: model, service: service) }
                .tabItem { Label("Discover", systemImage: "sparkle.magnifyingglass") }.tag(0)
            NavigationStack { SavedTrialsView() }
                .tabItem { Label("Saved", systemImage: "bookmark") }.tag(1)
            NavigationStack { SettingsView(service: service) }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(2)
        }
        .tint(Palette.ink)
    }
}
