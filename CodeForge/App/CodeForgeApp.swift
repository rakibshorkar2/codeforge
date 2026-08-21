import SwiftUI

@main
struct CodeForgeApp: App {
    @StateObject private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appEnvironment)
        }
    }
}
