import SwiftUI

struct AgentActivityTimelineView: View {
    let entries: [(toolName: String, success: Bool, filePath: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(entry.success ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        if index < entries.count - 1 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 20)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(entry.success ? .green : .red)
                            Text(entry.toolName)
                                .font(.caption.weight(.medium))
                        }
                        Text(entry.filePath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
