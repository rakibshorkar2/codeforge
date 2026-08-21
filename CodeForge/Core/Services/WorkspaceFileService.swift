import Foundation

enum WorkspaceFileError: Error, LocalizedError {
    case directoryCreationFailed(String)
    case fileCreationFailed(String)
    case readFailed(String)
    case writeFailed(String)
    case deleteFailed(String)
    case moveFailed(String)
    case copyFailed(String)
    case renameFailed(String)
    case pathTraversalDetected
    case itemNotFound(String)
    case notADirectory(String)
    case notAFile(String)
    case zipExtractionFailed(String)
    case zipCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path): return "Failed to create directory: \(path)"
        case .fileCreationFailed(let path): return "Failed to create file: \(path)"
        case .readFailed(let path): return "Failed to read: \(path)"
        case .writeFailed(let path): return "Failed to write: \(path)"
        case .deleteFailed(let path): return "Failed to delete: \(path)"
        case .moveFailed(let path): return "Failed to move: \(path)"
        case .copyFailed(let path): return "Failed to copy: \(path)"
        case .renameFailed(let path): return "Failed to rename: \(path)"
        case .pathTraversalDetected: return "Path traversal attack detected"
        case .itemNotFound(let path): return "Item not found: \(path)"
        case .notADirectory(let path): return "Not a directory: \(path)"
        case .notAFile(let path): return "Not a file: \(path)"
        case .zipExtractionFailed(let reason): return "ZIP extraction failed: \(reason)"
        case .zipCreationFailed(let reason): return "ZIP creation failed: \(reason)"
        }
    }
}

protocol WorkspaceFileServiceProtocol {
    var workspaceRoot: URL { get }
    func createDirectory(at url: URL) throws
    func createFile(at url: URL, contents: Data?) throws
    func readFile(at url: URL) throws -> Data
    func writeFile(at url: URL, data: Data) throws
    func deleteItem(at url: URL) throws
    func moveItem(from source: URL, to destination: URL) throws
    func copyItem(from source: URL, to destination: URL) throws
    func renameItem(at url: URL, to newName: String) throws -> URL
    func listDirectory(at url: URL) throws -> [URL]
    func fileExists(at url: URL) -> Bool
    func isDirectory(at url: URL) -> Bool
    func fileSize(at url: URL) throws -> UInt64
    func fileCount(in directory: URL) throws -> Int
    func sanitizePath(_ path: String, relativeTo base: URL) throws -> URL
    func extractZip(at source: URL, to destination: URL) throws
    func createZip(from source: URL, to destination: URL) throws
}

final class WorkspaceFileService: WorkspaceFileServiceProtocol {
    let workspaceRoot: URL

    private let fileManager = FileManager.default

    init(workspaceRoot: URL? = nil) {
        if let root = workspaceRoot {
            self.workspaceRoot = root
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.workspaceRoot = documents.appendingPathComponent("CodeForge", isDirectory: true)
        }
        ensureWorkspaceExists()
    }

    private func ensureWorkspaceExists() {
        if !fileManager.fileExists(atPath: workspaceRoot.path) {
            try? fileManager.createDirectory(at: workspaceRoot, withIntermediateDirectories: true)
        }
    }

    func createDirectory(at url: URL) throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw WorkspaceFileError.directoryCreationFailed(url.path)
        }
    }

    func createFile(at url: URL, contents: Data? = nil) throws {
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try createDirectory(at: directory)
        }
        let created = fileManager.createFile(atPath: url.path, contents: contents)
        if !created {
            throw WorkspaceFileError.fileCreationFailed(url.path)
        }
    }

    func readFile(at url: URL) throws -> Data {
        guard fileManager.fileExists(atPath: url.path) else {
            throw WorkspaceFileError.itemNotFound(url.path)
        }
        guard !isDirectory(at: url) else {
            throw WorkspaceFileError.notAFile(url.path)
        }
        guard let data = fileManager.contents(atPath: url.path) else {
            throw WorkspaceFileError.readFailed(url.path)
        }
        return data
    }

    func writeFile(at url: URL, data: Data) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw WorkspaceFileError.writeFailed(url.path)
        }
    }

    func deleteItem(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw WorkspaceFileError.itemNotFound(url.path)
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw WorkspaceFileError.deleteFailed(url.path)
        }
    }

    func moveItem(from source: URL, to destination: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw WorkspaceFileError.itemNotFound(source.path)
        }
        let destDir = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destDir.path) {
            try createDirectory(at: destDir)
        }
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw WorkspaceFileError.moveFailed("\(source.path) -> \(destination.path)")
        }
    }

    func copyItem(from source: URL, to destination: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw WorkspaceFileError.itemNotFound(source.path)
        }
        let destDir = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destDir.path) {
            try createDirectory(at: destDir)
        }
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw WorkspaceFileError.copyFailed("\(source.path) -> \(destination.path)")
        }
    }

    func renameItem(at url: URL, to newName: String) throws -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            throw WorkspaceFileError.itemNotFound(url.path)
        }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try fileManager.moveItem(at: url, to: newURL)
            return newURL
        } catch {
            throw WorkspaceFileError.renameFailed(url.path)
        }
    }

    func listDirectory(at url: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: url.path) else {
            throw WorkspaceFileError.itemNotFound(url.path)
        }
        guard isDirectory(at: url) else {
            throw WorkspaceFileError.notADirectory(url.path)
        }
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        return contents.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

    func fileSize(at url: URL) throws -> UInt64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? UInt64) ?? 0
    }

    func fileCount(in directory: URL) throws -> Int {
        guard isDirectory(at: directory) else { return 0 }
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        return contents.count
    }

    func sanitizePath(_ path: String, relativeTo base: URL) throws -> URL {
        let resolved = URL(fileURLWithPath: path).standardized
        let basePath = base.standardized.path
        guard resolved.path.hasPrefix(basePath) else {
            throw WorkspaceFileError.pathTraversalDetected
        }
        return resolved
    }

    func extractZip(at source: URL, to destination: URL) throws {
        try createDirectory(at: destination)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", source.path, "-d", destination.path]
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw WorkspaceFileError.zipExtractionFailed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            throw WorkspaceFileError.zipExtractionFailed("unzip exited with status \(process.terminationStatus)")
        }

        let extractedContents = try listDirectory(at: destination)
        for item in extractedContents {
            let sanitized = try sanitizePath(item.path, relativeTo: destination)
            guard sanitized.path == item.path else {
                throw WorkspaceFileError.pathTraversalDetected
            }
        }
    }

    func createZip(from source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", destination.path, source.lastPathComponent]
        process.currentDirectoryURL = source.deletingLastPathComponent()
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw WorkspaceFileError.zipCreationFailed(error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            throw WorkspaceFileError.zipCreationFailed("zip exited with status \(process.terminationStatus)")
        }
    }
}
