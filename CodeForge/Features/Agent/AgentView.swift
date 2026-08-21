import SwiftUI

struct AgentView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var messageText = ""
    @State private var selectedProject: Project?
    @State private var showProjectPicker = false

    private var session: AgentSession? {
        appEnvironment.agentManager.currentSession
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if session != nil {
                    chatHeader
                    Divider()
                    chatMessages
                    Divider()
                    chatInput
                } else {
                    projectSelectionView
                }
            }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if session != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            modeMenu
                            Divider()
                            Button("End Session", role: .destructive) {
                                appEnvironment.agentManager.stopSession()
                            }
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
        }
    }

    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session?.projectName ?? "")
                    .font(.headline)
                Text("Mode: \(appEnvironment.agentManager.config.mode.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if appEnvironment.agentManager.isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }
            Text("\(session?.iterationCount ?? 0)/\(appEnvironment.agentManager.config.maxIterations)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(session?.messages ?? []) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: session?.messages.count) { _, _ in
                if let lastMessage = session?.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageRow(_ message: AgentMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if message.role == .assistant {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    Text(message.role == .user ? "You" : "Agent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if message.role == .tool {
                        Text("Tool Result")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(message.content)
                    .font(.subheadline)
                    .padding(10)
                    .background(message.role == .user ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
    }

    private var chatInput: some View {
        HStack(spacing: 12) {
            TextField("Ask the agent...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appEnvironment.agentManager.isProcessing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var projectSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            Text("AI Coding Agent")
                .font(.title2.bold())

            Text("Select a project to start an AI coding session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Select Project") {
                showProjectPicker = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showProjectPicker) {
            AgentProjectPicker(selectedProject: $selectedProject) { project in
                startSession(for: project)
                showProjectPicker = false
            }
        }
    }

    private var modeMenu: some View {
        Menu("Mode") {
            ForEach(AgentMode.allCases, id: \.self) { mode in
                Button(action: {
                    appEnvironment.agentManager.config.mode = mode
                }) {
                    HStack {
                        Text(mode.rawValue)
                        if appEnvironment.agentManager.config.mode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session = session else { return }
        messageText = ""
        Task {
            await appEnvironment.agentManager.processMessage(text)
        }
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
}

struct AgentProjectPicker: View {
    @Binding var selectedProject: Project?
    let onSelect: (Project) -> Void
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(appEnvironment.projectManager.projects) { project in
                Button(action: {
                    selectedProject = project
                    onSelect(project)
                }) {
                    HStack {
                        Image(systemName: project.type.icon)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading) {
                            Text(project.name)
                                .font(.body)
                            Text(project.type.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
