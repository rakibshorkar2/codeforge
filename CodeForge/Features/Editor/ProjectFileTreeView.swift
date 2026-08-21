import SwiftUI

struct ProjectFileTreeView: View {
    let project: Project
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var files: [FileNode] = []
    @State private var isLoading = true
    @State private var showNewFile = false
    @State private var showNewFolder = false
    @State private var newName = ""
    @State private var renameTarget: FileNode?
    @State private var deleteTarget: FileNode?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading files...")
            } else if files.isEmpty {
                ContentUnavailableView(
                    "Empty Project",
                    systemImage: "folder",
                    description: Text("This project has no files yet.")
                )
            } else {
                List {
                    ForEach(files) { node in
                        FileNodeRow(
                            node: node,
                            fileService: appEnvironment.fileService,
                            onOpen: { openFile(at: $0) },
                            onRename: { renameTarget = $0 },
                            onDelete: {
                                deleteTarget = $0
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    newName = ""
                    showNewFile = true
                } label: {
                    Label("New File", systemImage: "doc.badge.plus")
                }
                Button {
                    newName = ""
                    showNewFolder = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }
        }
        .alert("New File", isPresented: $showNewFile) {
            TextField("filename.swift", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                createItem(name: newName, isDirectory: false)
            }
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter the file name with extension.")
        }
        .alert("New Folder", isPresented: $showNewFolder) {
            TextField("Folder name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                createItem(name: newName, isDirectory: true)
            }
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter the folder name.")
        }
        .alert("Rename", isPresented: .constant(renameTarget != nil)) {
            TextField("New name", text: $newName)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Rename") {
                if let target = renameTarget {
                    performRename(target, to: newName)
                }
                renameTarget = nil
            }
        } message: {
            Text("Enter a new name.")
        }
        .alert("Delete", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    performDelete(target)
                }
            }
        } message: {
            if let target = deleteTarget {
                Text("Delete \"\(target.name)\"? This cannot be undone.")
            }
        }
        .task { await loadFiles() }
    }

    private func loadFiles() async {
        isLoading = true
        let projectDir = appEnvironment.projectManager.projectDirectory(for: project)
        files = buildTree(at: projectDir)
        isLoading = false
    }

    private func buildTree(at url: URL) -> [FileNode] {
        guard let contents = try? appEnvironment.fileService.listDirectory(at: url) else { return [] }
        return contents.map { childURL in
            let isDir = appEnvironment.fileService.isDirectory(at: childURL)
            let children = isDir ? buildTree(at: childURL) : []
            return FileNode(name: childURL.lastPathComponent, url: childURL, isDirectory: isDir, children: children)
        }.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func createItem(name: String, isDirectory: Bool) {
        let projectDir = appEnvironment.projectManager.projectDirectory(for: project)
        let newURL = projectDir.appendingPathComponent(name)
        do {
            if isDirectory {
                try appEnvironment.fileService.createDirectory(at: newURL)
            } else {
                try appEnvironment.fileService.createFile(at: newURL, contents: Data())
            }
            Task { await loadFiles() }
        } catch {
            appEnvironment.handleError(error)
        }
    }

    private func performRename(_ node: FileNode, to newName: String) {
        do {
            _ = try appEnvironment.fileService.renameItem(at: node.url, to: newName)
            Task { await loadFiles() }
        } catch {
            appEnvironment.handleError(error)
        }
    }

    private func performDelete(_ node: FileNode) {
        do {
            try appEnvironment.fileService.deleteItem(at: node.url)
            Task { await loadFiles() }
        } catch {
            appEnvironment.handleError(error)
        }
    }

    private func openFile(at url: URL) {
        guard !appEnvironment.fileService.isDirectory(at: url) else { return }
        Task {
            do {
                let data = try appEnvironment.fileService.readFile(at: url)
                let content = String(data: data, encoding: .utf8) ?? ""
                appEnvironment.fileTabManager.openFile(at: url, content: content)
            } catch {
                appEnvironment.handleError(error)
            }
        }
    }
}

struct FileNode: Identifiable {
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]
    let id = UUID()
}

struct FileNodeRow: View {
    let node: FileNode
    let fileService: WorkspaceFileServiceProtocol
    var onOpen: (URL) -> Void
    var onRename: (FileNode) -> Void
    var onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children) { child in
                    FileNodeRow(
                        node: child,
                        fileService: fileService,
                        onOpen: onOpen,
                        onRename: onRename,
                        onDelete: onDelete
                    )
                }
            } label: {
                Label(node.name, systemImage: isExpanded ? "folder.fill" : "folder")
                    .font(.body)
            }
            .contextMenu {
                Button { onRename(node) } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                onOpen(node.url)
            } label: {
                Label {
                    Text(node.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: fileIcon)
                        .foregroundStyle(fileIconColor)
                }
            }
            .contextMenu {
                Button { onOpen(node.url) } label: {
                    Label("Open", systemImage: "doc.text")
                }
                Button { onRename(node) } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var fileIcon: String {
        let ext = node.url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "doc.text"
        case "js", "ts": return "curlybraces"
        case "html", "htm": return "globe"
        case "css": return "paintbrush"
        case "json": return "doc.plaintext"
        case "md": return "doc.richtext"
        case "c", "h": return "c.circle"
        case "cpp", "cc", "cxx": return "cpp.circle"
        case "rs": return "rust"
        case "go": return "globe.americas"
        case "java": return "cup.and.saucer"
        case "kt": return "k.circle"
        case "dart": return "d.circle"
        default: return "doc"
        }
    }

    private var fileIconColor: Color {
        let ext = node.url.pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "py": return .blue
        case "js": return .yellow
        case "ts": return .blue
        case "html", "htm": return .red
        case "css": return .purple
        case "json": return .green
        case "md": return .gray
        case "c", "h": return .gray
        case "cpp": return .blue
        case "rs": return .orange
        case "go": return .cyan
        case "java": return .red
        case "kt": return .purple
        case "dart": return .cyan
        default: return .gray
        }
    }
}
