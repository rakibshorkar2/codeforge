import SwiftUI

struct FilesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "doc.text",
                description: Text("Choose a project to browse its files.")
            )
            .navigationTitle("Files")
        }
    }
}
