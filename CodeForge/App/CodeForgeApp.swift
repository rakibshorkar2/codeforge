import SwiftUI

@main
struct CodeForgeApp: App {
    @StateObject private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appEnvironment)
                .alert("Error", isPresented: Binding(
                    get: { appEnvironment.currentError != nil },
                    set: { if !$0 { appEnvironment.dismissError() } }
                )) {
                    Button("OK", role: .cancel) {
                        appEnvironment.dismissError()
                    }
                } message: {
                    if let error = appEnvironment.currentError {
                        Text(error.localizedDescription)
                    }
                }
        }
    }
}
