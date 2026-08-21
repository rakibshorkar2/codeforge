import SwiftUI
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var selectedTab: Tab = .projects
    @Published var isLoading: Bool = false

    let projectManager: ProjectManagerProtocol
    let settingsManager: SettingsManagerProtocol

    init(
        projectManager: ProjectManagerProtocol = ProjectManager(),
        settingsManager: SettingsManagerProtocol = SettingsManager()
    ) {
        self.projectManager = projectManager
        self.settingsManager = settingsManager
    }
}
