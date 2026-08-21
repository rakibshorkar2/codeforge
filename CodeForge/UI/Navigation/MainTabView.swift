import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment

    var body: some View {
        TabView(selection: $appEnvironment.selectedTab) {
            ProjectsView()
                .tabItem {
                    Label(Tab.projects.title, systemImage: Tab.projects.systemImage)
                }
                .tag(Tab.projects)

            AgentView()
                .tabItem {
                    Label(Tab.agent.title, systemImage: Tab.agent.systemImage)
                }
                .tag(Tab.agent)

            FilesView()
                .tabItem {
                    Label(Tab.files.title, systemImage: Tab.files.systemImage)
                }
                .tag(Tab.files)

            BuildsView()
                .tabItem {
                    Label(Tab.builds.title, systemImage: Tab.builds.systemImage)
                }
                .tag(Tab.builds)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.systemImage)
                }
                .tag(Tab.settings)
        }
    }
}
