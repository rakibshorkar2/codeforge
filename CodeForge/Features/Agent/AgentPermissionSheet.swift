import SwiftUI

struct AgentPermissionSheet: View {
    @ObservedObject var permissionManager: AgentPermissionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let request = permissionManager.currentRequest {
            VStack(spacing: 20) {
                Image(systemName: request.level.destructive ? "exclamationmark.triangle.fill" : "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(request.level.destructive ? .orange : .blue)

                Text("Agent Permission")
                    .font(.title3.bold())

                VStack(spacing: 8) {
                    Text("The agent wants to:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(request.level.displayName)
                        .font(.headline)

                    Text(request.resource)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .lineLimit(2)
                }

                VStack(spacing: 12) {
                    Button(action: { respond(.allowOnce) }) {
                        Text("Allow Once")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { respond(.allowForSession) }) {
                        Text("Allow for Session")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    Button(action: { respond(.deny) }) {
                        Text("Deny")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 32)
            .presentationDetents([.height(400)])
        }
    }

    private func respond(_ decision: PermissionDecision) {
        guard let request = permissionManager.currentRequest else { return }
        permissionManager.respondToRequest(id: request.id, decision: decision)
        dismiss()
    }
}
