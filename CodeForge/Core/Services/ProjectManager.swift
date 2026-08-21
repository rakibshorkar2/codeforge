import Foundation
import Combine

protocol ProjectManagerProtocol {
    var projects: [Project] { get }
    var projectsPublisher: AnyPublisher<[Project], Never> { get }
    func createProject(name: String, type: ProjectType) async throws -> Project
    func deleteProject(id: UUID) async throws
    func renameProject(id: UUID, newName: String) async throws
    func duplicateProject(id: UUID, newName: String) async throws -> Project
    func loadProjects() async
    func projectExists(name: String) -> Bool
    func projectDirectory(for project: Project) -> URL
    func importProject(from url: URL, name: String) async throws -> Project
    func exportProject(_ project: Project) async throws -> URL
}

final class ProjectManager: ProjectManagerProtocol {
    @Published private(set) var projects: [Project] = []

    private let fileService: WorkspaceFileServiceProtocol
    private let persistenceKey = "com.codeforge.projects"

    var projectsPublisher: AnyPublisher<[Project], Never> {
        $projects.eraseToAnyPublisher()
    }

    init(fileService: WorkspaceFileServiceProtocol = WorkspaceFileService()) {
        self.fileService = fileService
        loadFromDisk()
    }

    func createProject(name: String, type: ProjectType) async throws -> Project {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkspaceFileError.fileCreationFailed("Project name cannot be empty")
        }

        guard !projectExists(name: name) else {
            throw WorkspaceFileError.directoryCreationFailed("A project named \"\(name)\" already exists")
        }

        let project = Project(name: name, type: type)
        let projectDir = projectDirectory(for: project)

        try ProjectTemplate.createProjectFiles(
            in: projectDir,
            projectName: name,
            type: type,
            fileService: fileService
        )

        projects.append(project)
        saveToDisk()
        return project
    }

    func deleteProject(id: UUID) async throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceFileError.itemNotFound("Project not found")
        }

        let project = projects[index]
        let projectDir = projectDirectory(for: project)

        if fileService.fileExists(at: projectDir) {
            try fileService.deleteItem(at: projectDir)
        }

        projects.remove(at: index)
        saveToDisk()
    }

    func renameProject(id: UUID, newName: String) async throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceFileError.itemNotFound("Project not found")
        }

        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkspaceFileError.renameFailed("Project name cannot be empty")
        }

        let oldProject = projects[index]
        let oldDir = projectDirectory(for: oldProject)

        var updatedProject = oldProject
        updatedProject.name = newName
        updatedProject.updatedAt = Date()
        let newDir = projectDirectory(for: updatedProject)

        if fileService.fileExists(at: oldDir) {
            try fileService.moveItem(from: oldDir, to: newDir)
        }

        projects[index] = updatedProject
        saveToDisk()
    }

    func duplicateProject(id: UUID, newName: String) async throws -> Project {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceFileError.itemNotFound("Project not found")
        }

        let original = projects[index]
        let originalDir = projectDirectory(for: original)

        let duplicate = Project(name: newName, type: original.type)
        let duplicateDir = projectDirectory(for: duplicate)

        if fileService.fileExists(at: originalDir) {
            try fileService.copyItem(from: originalDir, to: duplicateDir)
        }

        projects.append(duplicate)
        saveToDisk()
        return duplicate
    }

    func loadProjects() async {
        loadFromDisk()
    }

    func projectExists(name: String) -> Bool {
        projects.contains { $0.name == name }
    }

    func projectDirectory(for project: Project) -> URL {
        fileService.workspaceRoot
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(project.directoryName, isDirectory: true)
    }

    func importProject(from url: URL, name: String) async throws -> Project {
        let project = Project(name: name, type: .empty)
        let projectDir = projectDirectory(for: project)

        try fileService.createDirectory(at: projectDirectory(for: project).deletingLastPathComponent())

        if url.pathExtension.lowercased() == "zip" {
            try fileService.extractZip(at: url, to: projectDir)
        } else {
            try fileService.copyItem(from: url, to: projectDir.appendingPathComponent(url.lastPathComponent))
        }

        projects.append(project)
        saveToDisk()
        return project
    }

    func exportProject(_ project: Project) async throws -> URL {
        let projectDir = projectDirectory(for: project)
        guard fileService.fileExists(at: projectDir) else {
            throw WorkspaceFileError.itemNotFound("Project directory not found")
        }

        let tempDir = FileManager.default.temporaryDirectory
        let zipURL = tempDir.appendingPathComponent("\(project.directoryName).zip")

        if fileManager.fileExists(atPath: zipURL.path) {
            try? fileManager.removeItem(at: zipURL)
        }

        try fileService.createZip(from: projectDir, to: zipURL)
        return zipURL
    }

    private let fileManager = FileManager.default

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        let url = fileService.workspaceRoot.appendingPathComponent("projects.json")
        try? data.write(to: url, options: .atomic)
    }

    private func loadFromDisk() {
        let url = fileService.workspaceRoot.appendingPathComponent("projects.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Project].self, from: data) else {
            return
        }
        projects = decoded
    }
}
