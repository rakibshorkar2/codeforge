import Foundation
import Combine

protocol ProjectManagerProtocol {
    var projects: [Project] { get }
    var projectsPublisher: AnyPublisher<[Project], Never> { get }
    func addProject(name: String, path: String) -> Project
    func removeProject(id: UUID)
}

final class ProjectManager: ProjectManagerProtocol {
    @Published private(set) var projects: [Project] = []

    var projectsPublisher: AnyPublisher<[Project], Never> {
        $projects.eraseToAnyPublisher()
    }

    func addProject(name: String, path: String) -> Project {
        let project = Project(name: name, path: path)
        projects.append(project)
        return project
    }

    func removeProject(id: UUID) {
        projects.removeAll { $0.id == id }
    }
}
