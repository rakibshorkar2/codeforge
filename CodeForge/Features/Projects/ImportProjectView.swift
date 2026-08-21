import SwiftUI
import UniformTypeIdentifiers

struct ImportProjectView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter = false
    @State private var importType: ImportType = .zip
    @State private var isImporting = false
    @State private var errorMessage: String?

    enum ImportType: String, CaseIterable {
        case zip = "ZIP Archive"
        case folder = "Folder"
        case file = "Text/Code File"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Import Source") {
                    ForEach(ImportType.allCases, id: \.rawValue) { type in
                        Button {
                            importType = type
                            showImporter = true
                        } label: {
                            HStack {
                                Label(type.rawValue, systemImage: iconForType(type))
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if isImporting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Importing...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Import Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: allowedTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
        }
    }

    private var allowedTypes: [UTType] {
        switch importType {
        case .zip: return [.zipArchive]
        case .folder: return [.folder]
        case .file: return [.sourceCode, .plainText, .json, .propertyList]
        }
    }

    private func iconForType(_ type: ImportType) -> String {
        switch type {
        case .zip: return "archivebox"
        case .folder: return "folder"
        case .file: return "doc.text"
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFile(url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func importFile(_ url: URL) {
        isImporting = true
        errorMessage = nil

        let shouldAccess = url.startAccessingSecurityScopedResource()
        defer {
            if shouldAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let projectName = url.deletingPathExtension().lastPathComponent

        Task {
            do {
                _ = try await appEnvironment.projectManager.importProject(from: url, name: projectName)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isImporting = false
            }
        }
    }
}
