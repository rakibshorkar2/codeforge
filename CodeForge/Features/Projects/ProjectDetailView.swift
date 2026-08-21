import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var files: [URL] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading files...")
            } else if files.isEmpty {
                ContentUnavailableView(
                    "Empty Project",
                    systemImage: "folder",
                    description: Text("This project has no files yet.")
                )
            } else {
                ForEach(files, id: \.path) { file in
                    FileRowView(url: file, fileService: appEnvironment.fileService)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        exportProject()
                    } label: {
                        Label("Export as ZIP", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadFiles()
        }
    }

    private func loadFiles() async {
        isLoading = true
        let projectDir = appEnvironment.projectManager.projectDirectory(for: project)
        files = (try? appEnvironment.fileService.listDirectory(at: projectDir)) ?? []
        isLoading = false
    }

    private func exportProject() {
        Task {
            do {
                let zipURL = try await appEnvironment.projectManager.exportProject(project)
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [zipURL],
                        applicationActivities: nil
                    )
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(activityVC, animated: true)
                    }
                }
            } catch {
                appEnvironment.handleError(error)
            }
        }
    }
}

struct FileRowView: View {
    let url: URL
    let fileService: WorkspaceFileServiceProtocol

    var body: some View {
        HStack {
            Image(systemName: isDirectory ? "folder.fill" : "doc.text.fill")
                .foregroundStyle(isDirectory ? .blue : .gray)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.body)
                if !isDirectory {
                    Text(url.pathExtension.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isDirectory: Bool {
        fileService.isDirectory(at: url)
    }
}
