import SwiftUI

struct AgentSessionHistoryView: View {
    let projectID: String
    let onSelect: (PersistedAgentSession) -> Void
    let onDelete: (UUID) -> Void
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [PersistedAgentSession] = []

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("No previous agent sessions for this project.")
                    )
                } else {
                    ForEach(groupedSessions, id: \.0) { group, groupSessions in
                        Section(group) {
                            ForEach(groupSessions) { session in
                                Button(action: {
                                    onSelect(session)
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(session.messages.count) messages")
                                            .font(.body)
                                        Text(session.modifiedAt.formatted(.relative(presentation: .named)))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        onDelete(session.id)
                                        sessions.removeAll { $0.id == session.id }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadSessions() }
        }
    }

    private var groupedSessions: [(String, [PersistedAgentSession])] {
        let calendar = Calendar.current
        let today = sessions.filter { calendar.isDateInToday($0.modifiedAt) }
        let yesterday = sessions.filter { calendar.isDateInYesterday($0.modifiedAt) }
        let older = sessions.filter {
            !calendar.isDateInToday($0.modifiedAt) && !calendar.isDateInYesterday($0.modifiedAt)
        }
        var groups: [(String, [PersistedAgentSession])] = []
        if !today.isEmpty { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !older.isEmpty { groups.append(("Older", older)) }
        return groups
    }

    private func loadSessions() {
        sessions = appEnvironment.agentManager.loadSessions(forProject: projectID)
    }
}
