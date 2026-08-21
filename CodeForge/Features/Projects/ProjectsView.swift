import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var showNewProject = false
    @State private var showImport = false
    @State private var projectToDelete: Project?
    @State private var projectToRename: Project?
    @State private var renameText = ""
    @State private var showRenameSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if appEnvironment.projectManager.projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects Yet",
                        systemImage: "folder.badge.plus",
                        description: Text("Create a new project or import an existing one.")
                    )
                } else {
                    List {
                        ForEach(appEnvironment.projectManager.projects) { project in
                            NavigationLink {
                                ProjectDetailView(project: project)
                            } label: {
                                ProjectRowView(project: project)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    projectToDelete = project
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    projectToRename = project
                                    renameText = project.name
                                    showRenameSheet = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button {
                                    duplicateProject(project)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                .tint(.green)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showImport = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import Project")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Project")
                }
            }
            .sheet(isPresented: $showNewProject) {
                NewProjectView()
            }
            .sheet(isPresented: $showImport) {
                ImportProjectView()
            }
            .alert("Delete Project", isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let project = projectToDelete {
                        performDelete(project)
                    }
                }
            } message: {
                if let project = projectToDelete {
                    Text("Are you sure you want to delete \"\(project.name)\"? This cannot be undone.")
                }
            }
            .alert("Rename Project", isPresented: $showRenameSheet) {
                TextField("Project Name", text: $renameText)
                Button("Cancel", role: .cancel) { }
                Button("Rename") {
                    if let project = projectToRename, !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        performRename(project, newName: renameText)
                    }
                }
                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a new name for this project.")
            }
        }
    }

    private func performDelete(_ project: Project) {
        Task {
            do {
                try await appEnvironment.projectManager.deleteProject(id: project.id)
            } catch {
                appEnvironment.handleError(error)
            }
        }
    }

    private func performRename(_ project: Project, newName: String) {
        Task {
            do {
                try await appEnvironment.projectManager.renameProject(id: project.id, newName: newName)
            } catch {
                appEnvironment.handleError(error)
            }
        }
    }

    private func duplicateProject(_ project: Project) {
        Task {
            do {
                let duplicateName = "\(project.name) Copy"
                _ = try await appEnvironment.projectManager.duplicateProject(id: project.id, newName: duplicateName)
            } catch {
                appEnvironment.handleError(error)
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: project.type.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text(project.name)
                    .font(.headline)
            }
            HStack(spacing: 12) {
                Label(project.type.language, systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(project.type.displayName, systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(project.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
