import SwiftUI

struct FilesView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var selectedProject: Project?
    @State private var showProjectPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if let project = selectedProject {
                    if appEnvironment.fileTabManager.openTabs.isEmpty {
                        ProjectFileTreeView(project: project)
                    } else {
                        editorContent
                    }
                } else {
                    ContentUnavailableView(
                        "Select a Project",
                        systemImage: "doc.text",
                        description: Text("Choose a project to browse and edit files.")
                    )
                }
            }
            .navigationTitle("Files")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showProjectPicker = true
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                    }
                    .accessibilityLabel("Select Project")
                }

                if appEnvironment.fileTabManager.openTabs.count > 1 {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(appEnvironment.fileTabManager.openTabs) { tab in
                                Button {
                                    appEnvironment.fileTabManager.switchToTab(id: tab.id)
                                } label: {
                                    HStack {
                                        Text(tab.filename)
                                        if tab.isModified {
                                            Circle()
                                                .fill(.orange)
                                                .frame(width: 6, height: 6)
                                        }
                                        if tab.id == appEnvironment.fileTabManager.activeTabID {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            Divider()
                            Button("Close All") {
                                appEnvironment.fileTabManager.closeAllTabs()
                            }
                        } label: {
                            Label("Tabs", systemImage: "square.on.square")
                        }
                    }
                }
            }
            .sheet(isPresented: $showProjectPicker) {
                ProjectPickerSheet(selectedProject: $selectedProject)
            }
        }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            if appEnvironment.fileTabManager.openTabs.count > 1 {
                tabBar
            }

            if let tab = appEnvironment.fileTabManager.activeTab {
                editorTabContent(for: tab)
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appEnvironment.fileTabManager.openTabs) { tab in
                    tabButton(for: tab)
                }
            }
        }
        .background(.bar)
        Divider()
    }

    private func tabButton(for tab: EditorTab) -> some View {
        Button {
            appEnvironment.fileTabManager.switchToTab(id: tab.id)
        } label: {
            HStack(spacing: 6) {
                Text(tab.filename)
                    .font(.caption)
                    .lineLimit(1)
                if tab.isModified {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
                Button {
                    appEnvironment.fileTabManager.closeTab(id: tab.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tab.id == appEnvironment.fileTabManager.activeTabID ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func editorTabContent(for tab: EditorTab) -> some View {
        CodeEditorView(
            tab: tab,
            content: Binding(
                get: { tab.content },
                set: { appEnvironment.fileTabManager.updateContent(forTabID: tab.id, content: $0) }
            )
        )
    }
}

struct ProjectPickerSheet: View {
    @Binding var selectedProject: Project?
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(appEnvironment.projectManager.projects) { project in
                    Button {
                        selectedProject = project
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: project.type.icon)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text(project.name)
                                    .foregroundStyle(.primary)
                                Text(project.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedProject?.id == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
