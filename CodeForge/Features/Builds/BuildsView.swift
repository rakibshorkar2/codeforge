import SwiftUI

struct BuildsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Builds Yet",
                systemImage: "hammer",
                description: Text("Build and run your projects here.")
            )
            .navigationTitle("Builds")
        }
    }
}
