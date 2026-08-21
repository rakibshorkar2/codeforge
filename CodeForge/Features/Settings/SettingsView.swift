import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var selectedAppearance: AppearanceOption = .system
    @State private var fontSize: Double = 16.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $selectedAppearance) {
                        ForEach(AppearanceOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedAppearance) { _, newValue in
                        appEnvironment.settingsManager.setAppearance(newValue)
                    }
                }

                Section("Editor") {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(fontSize))pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $fontSize, in: 10...24, step: 1)
                        .onChange(of: fontSize) { _, newValue in
                            appEnvironment.settingsManager.setFontSize(newValue)
                        }
                }

                Section("AI Providers") {
                    NavigationLink(destination: AIProvidersSettingsView()) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundStyle(.purple)
                            Text("AI Providers")
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                selectedAppearance = appEnvironment.settingsManager.appearance
                fontSize = appEnvironment.settingsManager.fontSize
            }
        }
    }
}
