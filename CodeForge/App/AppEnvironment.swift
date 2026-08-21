import SwiftUI
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var selectedTab: Tab = .projects
    @Published var isLoading: Bool = false
    @Published var currentError: AppError?

    let projectManager: ProjectManagerProtocol
    let settingsManager: SettingsManagerProtocol
    let fileService: WorkspaceFileServiceProtocol
    let fileTabManager: FileTabManager

    init(
        projectManager: ProjectManagerProtocol? = nil,
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        fileService: WorkspaceFileServiceProtocol = WorkspaceFileService(),
        fileTabManager: FileTabManager = FileTabManager()
    ) {
        self.fileService = fileService
        self.settingsManager = settingsManager
        self.projectManager = projectManager ?? ProjectManager(fileService: fileService)
        self.fileTabManager = fileTabManager
    }

    func handleError(_ error: Error) {
        if let appError = error as? AppError {
            currentError = appError
        } else if let fileError = error as? WorkspaceFileError {
            currentError = .filesystem(FileError.custom(fileError.localizedDescription))
        } else {
            currentError = .unknown(error.localizedDescription)
        }
    }

    func dismissError() {
        currentError = nil
    }
}
