import SwiftUI

struct AgentView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var messageText = ""
    @State private var selectedProject: Project?
    @State private var showProjectPicker = false
    @State private var showSettings = false
    @State private var showSessionHistory = false
    @State private var showChangeReview = false
    @State private var attachedFiles: [String] = []

    private var session: AgentSession? {
        appEnvironment.agentManager.currentSession
    }

    var body: some View {
        NavigationStack {
            Group {
                if session != nil {
                    chatWorkspace
                } else {
                    projectSelectionView
                }
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if session != nil {
                            Button(action: { showSessionHistory = true }) {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showProjectPicker) {
                AgentProjectPicker(selectedProject: $selectedProject) { project in
                    startSession(for: project)
                    showProjectPicker = false
                }
            }
            .sheet(isPresented: $showSettings) {
                AgentSettingsSheet(config: appEnvironment.agentManager.config, permissionManager: appEnvironment.agentManager.permissionManager)
            }
            .sheet(isPresented: $showSessionHistory) {
                AgentSessionHistoryView(projectID: session?.projectID ?? "") { persisted in
                    appEnvironment.agentManager.resumeSession(persisted, requestService: appEnvironment.aiRequestService)
                    showSessionHistory = false
                } onDelete: { id in
                    appEnvironment.agentManager.deleteSession(id: id)
                }
            }
            .sheet(isPresented: $showChangeReview) {
                AgentChangeReviewView(tracker: appEnvironment.agentManager.changeTracker, workspace: session?.workspace ?? "")
            }
        }
    }

    private var chatWorkspace: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()
            chatMessages
            if let error = appEnvironment.agentManager.lastError {
                errorBanner(error)
            }
            Divider()
            chatInput
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session?.projectName ?? "")
                    .font(.subheadline.weight(.semibold))
                Text(config.mode.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !appEnvironment.agentManager.statusMessage.isEmpty {
                Text(appEnvironment.agentManager.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.purple)
                    .lineLimit(1)
            }
            if appEnvironment.agentManager.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            }
            if !appEnvironment.agentManager.changeTracker.pendingChanges.isEmpty {
                Button(action: { showChangeReview = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.diff")
                        Text("\(appEnvironment.agentManager.changeTracker.pendingChanges.count)")
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(session?.messages ?? []) { message in
                        messageRow(message)
                            .id(message.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if !appEnvironment.agentManager.streamingContent.isEmpty && (session?.isRunning ?? false) {
                        streamingRow
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session?.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    if let last = session?.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: appEnvironment.agentManager.streamingContent) { _, _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    private func messageRow(_ message: AgentMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if message.role == .assistant {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    Text(message.role == .user ? "You" : message.role == .tool ? "Tool" : "Agent")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    if message.role == .tool {
                        Image(systemName: message.content.contains("Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(message.content.contains("Error") ? .red : .green)
                    }
                }

                if message.role == .tool {
                    toolResultCard(message)
                } else {
                    Text(message.content)
                        .font(.subheadline)
                        .padding(12)
                        .background(message.role == .user ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            if message.role != .user { Spacer(minLength: 48) }
        }
    }

    private func toolResultCard(_ message: AgentMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let isError = message.content.contains("Error")
            Text(isError ? "Failed" : "Completed")
                .font(.caption2.weight(.medium))
                .foregroundStyle(isError ? .red : .green)
            Text(String(message.content.prefix(200)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isError ? Color.red.opacity(0.05) : Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isError ? Color.red.opacity(0.2) : Color.green.opacity(0.2), lineWidth: 1)
        )
    }

    private var streamingRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer(minLength: 48)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text("Agent")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    ProgressView()
                        .scaleEffect(0.5)
                }
                Text(appEnvironment.agentManager.streamingContent)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color.purple.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Spacer(minLength: 48)
        }
        .id("streaming")
    }

    private func errorBanner(_ error: AgentError) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(error.message)
                    .font(.caption)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Button("Retry") {
                        Task { await appEnvironment.agentManager.retryLastMessage() }
                    }
                    .font(.caption.weight(.medium))
                    Button("Dismiss") {
                        appEnvironment.agentManager.lastError = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var chatInput: some View {
        HStack(spacing: 12) {
            if !attachedFiles.isEmpty {
                Button(action: { attachedFiles.removeAll() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                        Text("\(attachedFiles.count)")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            TextField("Ask anything...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .font(.subheadline)

            if appEnvironment.agentManager.isProcessing {
                Button(action: { appEnvironment.agentManager.cancel() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var projectSelectionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(.purple)

            VStack(spacing: 8) {
                Text("AI Coding Agent")
                    .font(.title3.bold())
                Text("Select a project to start an AI coding session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showProjectPicker = true }) {
                Label("Select Project", systemImage: "folder.badge.questionmark")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startSession(for project: Project) {
        let workspace = (try? appEnvironment.fileService.baseDirectory(for: project))?.path ?? ""
        appEnvironment.agentManager.startSession(
            projectID: project.id.uuidString,
            projectName: project.name,
            workspace: workspace,
            requestService: appEnvironment.aiRequestService
        )
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, session != nil else { return }
        messageText = ""
        let finalMessage = attachedFiles.isEmpty ? text : "\(text)\n\nAttached files: \(attachedFiles.joined(separator: ", "))"
        attachedFiles.removeAll()
        Task {
            await appEnvironment.agentManager.processMessage(finalMessage)
        }
    }

    private var config: AgentConfig {
        appEnvironment.agentManager.config
    }
}

struct AgentProjectPicker: View {
    @Binding var selectedProject: Project?
    let onSelect: (Project) -> Void
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if appEnvironment.projectManager.projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder.badge.plus",
                        description: Text("Create a project first to use the AI agent.")
                    )
                } else {
                    ForEach(appEnvironment.projectManager.projects) { project in
                        Button(action: {
                            selectedProject = project
                            onSelect(project)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: project.type.icon)
                                    .font(.title3)
                                    .foregroundStyle(.purple)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.body)
                                    Text(project.type.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
