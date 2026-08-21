import SwiftUI

struct AIProvidersSettingsView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: AIProvidersViewModel

    init() {
        _viewModel = StateObject(wrappedValue: AIProvidersViewModel(providerManager: AIProviderManager()))
    }

    var body: some View {
        Form {
            Section {
                ForEach(viewModel.providers) { provider in
                    NavigationLink(destination: AIProviderDetailView(provider: provider, viewModel: viewModel)) {
                        HStack {
                            Image(systemName: provider.type.icon)
                                .frame(width: 30)
                                .foregroundStyle(provider.isEnabled ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name)
                                    .font(.body)
                                Text(provider.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.hasAPIKey(providerID: provider.id) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            }
                            if !provider.isEnabled {
                                Text("Off")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: viewModel.removeProviders)
            } header: {
                Text("Configured Providers")
            } footer: {
                if viewModel.providers.isEmpty {
                    Text("No AI providers configured. Add one to get started.")
                }
            }

            Section {
                ForEach(AIProviderType.allCases) { type in
                    Button(action: {
                        viewModel.addProvider(type: type)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Add \(type.displayName)")
                        }
                    }
                }
            } header: {
                Text("Add Provider")
            }
        }
        .navigationTitle("AI Providers")
        .onChange(of: viewModel.providers) { _, _ in
            appEnvironment.aiProviderManager.loadPersistedProviders()
        }
    }
}

struct AIProviderDetailView: View {
    let provider: ProviderConfig
    @ObservedObject var viewModel: AIProvidersViewModel
    @State private var editedName: String = ""
    @State private var editedBaseURL: String = ""
    @State private var isEnabled: Bool = true
    @State private var showAPIKeyEntry = false
    @State private var apiKey: String = ""
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Provider") {
                TextField("Name", text: $editedName)
                    .onChange(of: editedName) { _, newValue in
                        viewModel.updateProviderName(providerID: provider.id, name: newValue)
                    }

                TextField("Base URL", text: $editedBaseURL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .onChange(of: editedBaseURL) { _, newValue in
                        viewModel.updateProviderBaseURL(providerID: provider.id, url: newValue)
                    }

                Toggle("Enabled", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        viewModel.toggleProvider(providerID: provider.id, enabled: newValue)
                    }
            }

            Section("API Key") {
                if viewModel.hasAPIKey(providerID: provider.id) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("API key configured")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Update") {
                            showAPIKeyEntry = true
                        }
                        Button("Delete", role: .destructive) {
                            viewModel.deleteAPIKey(providerID: provider.id)
                        }
                    }
                } else {
                    Button("Add API Key") {
                        showAPIKeyEntry = true
                    }
                }
            }

            Section("Model") {
                Picker("Active Model", selection: Binding(
                    get: { viewModel.selectedModelID(for: provider.id) },
                    set: { viewModel.selectModel(providerID: provider.id, modelID: $0) }
                )) {
                    ForEach(provider.availableModels) { model in
                        Text(model.displayName).tag(model.id as String?)
                    }
                }
            }

            Section {
                Button("Delete Provider", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(provider.name)
        .onAppear {
            editedName = provider.name
            editedBaseURL = provider.baseURL
            isEnabled = provider.isEnabled
        }
        .alert("API Key", isPresented: $showAPIKeyEntry) {
            SecureField("Enter API Key", text: $apiKey)
                .textContentType(.password)
            Button("Save") {
                viewModel.saveAPIKey(providerID: provider.id, key: apiKey)
                apiKey = ""
            }
            Button("Cancel", role: .cancel) {
                apiKey = ""
            }
        } message: {
            Text("Enter your \(provider.type.displayName) API key. This will be stored securely in the Keychain.")
        }
        .alert("Delete Provider", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteProvider(id: provider.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(provider.name)\"? This will also remove the stored API key.")
        }
    }
}

@MainActor
final class AIProvidersViewModel: ObservableObject {
    @Published var providers: [ProviderConfig] = []

    private let providerManager: AIProviderManagerProtocol

    init(providerManager: AIProviderManagerProtocol) {
        self.providerManager = providerManager
        loadProviders()
    }

    func loadProviders() {
        providers = providerManager.providers
    }

    func addProvider(type: AIProviderType) {
        let config = ProviderConfig(
            name: type.displayName,
            type: type,
            baseURL: type.defaultBaseURL,
            isEnabled: true
        )
        providerManager.addProvider(config)
        loadProviders()
    }

    func removeProviders(at offsets: IndexSet) {
        for index in offsets {
            providerManager.removeProvider(id: providers[index].id)
        }
        loadProviders()
    }

    func deleteProvider(id: UUID) {
        providerManager.removeProvider(id: id)
        loadProviders()
    }

    func updateProviderName(providerID: UUID, name: String) {
        guard var provider = providers.first(where: { $0.id == providerID }) else { return }
        provider.name = name
        providerManager.updateProvider(provider)
        loadProviders()
    }

    func updateProviderBaseURL(providerID: UUID, url: String) {
        guard var provider = providers.first(where: { $0.id == providerID }) else { return }
        provider.baseURL = url
        providerManager.updateProvider(provider)
        loadProviders()
    }

    func toggleProvider(providerID: UUID, enabled: Bool) {
        guard var provider = providers.first(where: { $0.id == providerID }) else { return }
        provider.isEnabled = enabled
        providerManager.updateProvider(provider)
        loadProviders()
    }

    func selectModel(providerID: UUID, modelID: String?) {
        providerManager.setSelectedModel(providerID: providerID, modelID: modelID ?? "")
        loadProviders()
    }

    func selectedModelID(for providerID: UUID) -> String? {
        providers.first(where: { $0.id == providerID })?.selectedModelID
    }

    func saveAPIKey(providerID: UUID, key: String) {
        try? providerManager.saveAPIKey(providerID: providerID, key: key)
    }

    func deleteAPIKey(providerID: UUID) {
        try? providerManager.deleteAPIKey(providerID: providerID)
    }

    func hasAPIKey(providerID: UUID) -> Bool {
        providerManager.hasAPIKey(providerID: providerID)
    }
}
