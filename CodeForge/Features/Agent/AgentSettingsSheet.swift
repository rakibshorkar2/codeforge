import SwiftUI

struct AgentSettingsSheet: View {
    @ObservedObject var config: AgentConfigObservable
    @ObservedObject var permissionManager: AgentPermissionManager
    @Environment(\.dismiss) private var dismiss

    init(config: AgentConfig, permissionManager: AgentPermissionManager) {
        self.config = AgentConfigObservable(from: config)
        self.permissionManager = permissionManager
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Agent Mode") {
                    Picker("Mode", selection: $config.mode) {
                        ForEach(AgentMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(config.mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Limits") {
                    Stepper("Max Iterations: \(config.maxIterations)", value: $config.maxIterations, in: 5...50, step: 5)
                    Stepper("Max Context: \(config.maxContextTokens / 1000)K", value: $config.maxContextTokens, in: 2000...32000, step: 2000)
                    Stepper("Max Response: \(config.maxResponseTokens)", value: $config.maxResponseTokens, in: 512...16384, step: 512)
                }

                Section("Permissions") {
                    ForEach(PermissionLevel.allCases, id: \.self) { level in
                        HStack {
                            Image(systemName: level.icon)
                                .frame(width: 24)
                            Text(level.displayName)
                            Spacer()
                            Picker("", selection: permissionBinding(for: level)) {
                                ForEach(PermissionPolicy.allCases, id: \.self) { policy in
                                    Text(policy.displayName).tag(policy)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Rollback Session")
                        Spacer()
                        Button("Rollback", role: .destructive) {
                            // Handled by parent
                        }
                    }
                }
            }
            .navigationTitle("Agent Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        config.syncToOriginal()
                        dismiss()
                    }
                }
            }
        }
    }

    private func permissionBinding(for level: PermissionLevel) -> Binding<PermissionPolicy> {
        Binding(
            get: { permissionManager.policy(for: level) },
            set: { permissionManager.setPolicy($0, for: level) }
        )
    }
}

@MainActor
final class AgentConfigObservable: ObservableObject {
    @Published var mode: AgentMode
    @Published var maxIterations: Int
    @Published var maxContextTokens: Int
    @Published var maxResponseTokens: Int

    private let original: AgentConfig

    init(from config: AgentConfig) {
        self.original = config
        self.mode = config.mode
        self.maxIterations = config.maxIterations
        self.maxContextTokens = config.maxContextTokens
        self.maxResponseTokens = config.maxResponseTokens
    }

    func syncToOriginal() {
        original.mode = mode
        original.maxIterations = maxIterations
        original.maxContextTokens = maxContextTokens
        original.maxResponseTokens = maxResponseTokens
    }
}
