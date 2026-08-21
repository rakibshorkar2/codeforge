import SwiftUI

struct AgentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "AI Coding Workspace",
                systemImage: "brain.head.profile",
                description: Text("AI-powered coding assistance will be available here.")
            )
            .navigationTitle("Agent")
        }
    }
}
