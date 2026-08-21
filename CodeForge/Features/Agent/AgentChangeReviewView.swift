import SwiftUI

struct AgentChangeReviewView: View {
    let tracker: AgentChangeTracker
    let workspace: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if tracker.pendingChanges.isEmpty {
                    ContentUnavailableView(
                        "No Changes",
                        systemImage: "checkmark.circle",
                        description: Text("No file changes have been made by the agent yet.")
                    )
                } else {
                    Section {
                        ForEach(tracker.pendingChanges) { change in
                            changeRow(change)
                        }
                    } header: {
                        Text("\(tracker.pendingChanges.count) file(s) changed")
                    }
                }
            }
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func changeRow(_ change: AgentChangeTracker.FileChange) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: operationIcon(change.operation))
                    .foregroundStyle(operationColor(change.operation))
                Text(change.path)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(change.operation.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(operationColor(change.operation).opacity(0.15))
                    .clipShape(Capsule())
            }

            if let oldContent = change.oldContent, let newContent = change.newContent, change.operation == .modify {
                diffPreview(old: oldContent, new: newContent)
            } else if change.operation == .create, let content = change.newContent {
                contentPreview(content)
            } else if change.operation == .delete {
                Text("File will be deleted")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private func diffPreview(old: String, new: String) -> some View {
        let oldLines = old.components(separatedBy: .newlines)
        let newLines = new.components(separatedBy: .newlines)
        return VStack(alignment: .leading, spacing: 2) {
            let added = newLines.count - oldLines.count
            let removed = oldLines.count - newLines.count
            HStack(spacing: 12) {
                if added > 0 {
                    Label("+\(added)", systemImage: "plus.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                if removed > 0 {
                    Label("-\(removed)", systemImage: "minus.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            Text(String(new.prefix(300)))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(6)
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func contentPreview(_ content: String) -> some View {
        Text(String(content.prefix(300)))
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(6)
            .padding(8)
            .background(Color.green.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func operationIcon(_ op: AgentChangeTracker.FileChange.Operation) -> String {
        switch op {
        case .create: return "plus.circle.fill"
        case .modify: return "pencil.circle.fill"
        case .delete: return "trash.circle.fill"
        case .rename: return "arrow.right.circle.fill"
        case .move: return "arrow.up.right.circle.fill"
        }
    }

    private func operationColor(_ op: AgentChangeTracker.FileChange.Operation) -> Color {
        switch op {
        case .create: return .green
        case .modify: return .blue
        case .delete: return .red
        case .rename: return .orange
        case .move: return .purple
        }
    }
}
